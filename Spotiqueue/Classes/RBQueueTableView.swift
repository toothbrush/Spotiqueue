//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import Combine
import SpotifyWebAPI

class RBQueueTableView: RBTableView {
    var cancellables: Set<AnyCancellable> = []

    override func associatedArrayController() -> NSArrayController {
        AppDelegate.appDelegate().queueArrayController
    }

    @objc func paste(_ sender: AnyObject?) {
        AppDelegate.appDelegate().isSearching = true
        guard let contents = NSPasteboard.general.pasteboardItems?.first?.string(forType: .string) else { return }
        addTracksToQueue(from: contents)
    }

    /// This function is hopefully useful for calling from Guile land. e.g.
    ///
    /// ```
    /// (enqueue "spotify:album:asdf" "spotify:track:1234")
    /// ```
    ///
    func addTracksToQueue(from manyUris: [String]) {
        addTracksToQueue(from: manyUris.joined(separator: "\n"))
    }

    func addTracksToQueue(from contents: String) {
        AppDelegate.appDelegate().isSearching = true
        let incoming_uris = RBSpotifyAPI.sanitiseIncomingURIBlob(pasted_blob: contents)
        guard !incoming_uris.isEmpty else {
            AppDelegate.appDelegate().isSearching = false
            return
        }

        if incoming_uris.allSatisfy({ $0.uri.hasPrefix("spotify:track:") }) {
            // we can use the fancy batching-fetch-songs mechanism.
            var stub_songs: [RBSpotifySong] = []
            for s in incoming_uris {
                logger.info("Hydrating song \(s)")
                stub_songs.append(
                    RBSpotifySong(spotify_uri: s.uri)
                )
            }
            AppDelegate.appDelegate().queueArrayController.add(contentsOf: stub_songs)

            AppDelegate.appDelegate().runningTasks = Int((Double(stub_songs.count) / 50.0).rounded(.up))
            for chunk in stub_songs.chunked(size: 50) {
                AppDelegate.appDelegate().spotify.api.tracks(chunk.map({ $0.spotify_uri }))
                    .receive(on: RunLoop.main)
                    .sink(
                        receiveCompletion: { completion in
                            AppDelegate.appDelegate().runningTasks -= 1
                            logger.info("completion: \(completion)")
                        },
                        receiveValue: { tracks in
                            for (index, track) in tracks.enumerated() {
                                logger.info("result[\(index)]: \(track?.name ?? "")")
                                if let track = track {
                                    chunk[index].hydrate(with: track)
                                } else {
                                    // we got a nil from the API, remove from queue.
                                }
                            }
                        }
                    )
                    .store(in: &cancellables)
            }
        } else {
            // deal with pasted items one-by-one
            Publishers.mergeMappedRetainingOrder(incoming_uris,
                                                 mapTransform: { AppDelegate.appDelegate().spotify.api.dealWithUnknownSpotifyURI($0) })
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    AppDelegate.appDelegate().isSearching = false
                    logger.info("completion: \(completion)")
                },
                receiveValue: { tracks in
                    AppDelegate.appDelegate()
                        .insertTracks(newRows: tracks.joined().map({ RBSpotifySong(track: $0)}),
                                      in: .Queue,
                                      at_the_top: false,
                                      and_then_advance: false)
                })
                .store(in: &cancellables)
        }
    }

    func enter() {
        guard self.selectedRowIndexes.count == 1 else {
            logger.info("hmm, enter pressed on non-single track selection..")
            NSSound.beep()
            return
        }
        AppDelegate.appDelegate().queue.removeFirst(self.selectedRow)
        _ = AppDelegate.appDelegate().playNextQueuedTrack()
    }

    func delete_selected_tracks() {
        guard self.selectedRowIndexes.count > 0 else {
            NSSound.beep()
            return
        }
        let firstDeletionIdx = self.selectedRowIndexes.first!
        AppDelegate.appDelegate().queue.remove(atOffsets: self.selectedRowIndexes)
        self.selectRow(row: firstDeletionIdx)
    }

    override func browseDetailsOnRow() {
        guard !AppDelegate.appDelegate().isSearching else {
            return
        }
        guard selectedRowIndexes.count == 1 else {
            NSSound.beep()
            return
        }

        if let songRow: RBSpotifySong = self.associatedArrayController().selectedObjects.first as? RBSpotifySong {
            AppDelegate.appDelegate().browseDetails(for: songRow, consideringHistory: false)
        }
    }

    func moveSelectionUp() {
        guard !self.selectedRowIndexes.isEmpty else {
            NSSound.beep()
            return
        }
        if let first = self.selectedRowIndexes.first, first > 0 {
            AppDelegate.appDelegate().queue.move(fromOffsets: self.selectedRowIndexes, toOffset: first - 1)
            self.scrollRowToVisible((first - 2).clamped(fromInclusive: 0, toInclusive: self.numberOfRows - 1))
        }
    }

    func moveSelectionDown() {
        guard !self.selectedRowIndexes.isEmpty else {
            NSSound.beep()
            return
        }
        if let last = self.selectedRowIndexes.last, last + 1 < self.numberOfRows  {
            AppDelegate.appDelegate().queue.move(fromOffsets: self.selectedRowIndexes, toOffset: last + 2)
            self.scrollRowToVisible((last + 2).clamped(fromInclusive: 0, toInclusive: self.numberOfRows - 1))
        }
    }

    let ADD_TO_PLAYLIST_CHUNKSIZE: Int = 100 // The maximum supported by the Spotify API.
    /*
     It's not beautiful, but i had immense trouble with a) chunking a bunch of tracks and adding them one after the other to a playlist.  Using MergeMany still resulted in jumbled playlists, perhaps because the Spotify API doesn't like being hit that quickly in succession.  Anyway this "tail recursive" approach is a bit of an abomination (special callout for the 2s delay) but at least it's reliable.
     */
    private func addItemsToPlaylist(spotify: RBSpotifyAPI,
                                    playlist_uri: String,
                                    items: [SpotifyURIConvertible],
                                    step: Int = 0) {
        // beware, this will be called in a background thread, so no UI.
        guard !items.isEmpty else {
            return
        }
        let chunk: [SpotifyURIConvertible] = Array(items.prefix(ADD_TO_PLAYLIST_CHUNKSIZE))
        let rest:  [SpotifyURIConvertible] = Array(items.dropFirst(ADD_TO_PLAYLIST_CHUNKSIZE))
        spotify.api.addToPlaylist(playlist_uri, uris: chunk)
            .delay(for: 2, scheduler: RunLoop.main)
            .sink { completion in
                switch completion {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            logger.error("Couldn't add batch to playlist: \(error.localizedDescription)")
                        }
                    case .finished:
                        DispatchQueue.main.async {
                            logger.info("[step \(step)] Done adding chunks to playlist \(playlist_uri).")
                        }
                        self.addItemsToPlaylist(spotify: spotify,
                                                playlist_uri: playlist_uri,
                                                items: rest,
                                                step: step + 1)
                }
            } receiveValue: { snapshotIds in
                DispatchQueue.main.async {
                    logger.info("[step \(step)] Updated playlist, snapshot id: \(snapshotIds)")
                }
            }
            .store(in: &cancellables)
    }

    func saveCurrentQueueAsPlaylist() {
        guard !AppDelegate.appDelegate().queue.isEmpty else {
            // saving an empty queue makes no sense.
            return
        }
        let alert = NSAlert()
        alert.messageText = "Create Playlist"
        alert.informativeText = "Name for new playlist:"
        alert.alertStyle = NSAlert.Style.informational
        let playlistNameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        playlistNameField.stringValue = String(format: "%@ – %@",
                                               AppDelegate.appDelegate().queue.first!.artist,
                                               AppDelegate.appDelegate().queue.first!.album)
        alert.accessoryView = playlistNameField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = playlistNameField
        alert.beginSheetModal(for: AppDelegate.appDelegate().window) { result in
            if result == .alertFirstButtonReturn {
                // OK button
                let spotify = AppDelegate.appDelegate().spotify
                logger.info(playlistNameField.stringValue.strip())
                logger.info(String(format: "%@ created by Spotiqueue", Date().string(format: "yyyy-MM-dd")))
                let details = PlaylistDetails(name: playlistNameField.stringValue.strip(),
                                              isPublic: false,
                                              isCollaborative: false,
                                              description:
                                                String(format: "%@ created by Spotiqueue", Date().string(format: "yyyy-MM-dd")))
                var createdPlaylistURI = ""
                let itemsToAddToPlaylist: [SpotifyURIConvertible] =
                    AppDelegate.appDelegate().queue.map { song in
                        song.spotify_uri
                    }

                spotify.api.createPlaylist(for: spotify.currentUser!.uri, details)
                    .sink { completion in
                        switch completion {
                            case .failure(let error):
                                logger.error("Couldn't create playlist: \(error.localizedDescription)")
                            case .finished:
                                logger.info("Done with playlist creation: \(createdPlaylistURI).")
                                self.addItemsToPlaylist(spotify: spotify,
                                                        playlist_uri: createdPlaylistURI,
                                                        items: itemsToAddToPlaylist)
                        }
                    } receiveValue: { playlist in
                        createdPlaylistURI = playlist.uri
                        logger.info("Created playlist, uri: \(createdPlaylistURI)")
                    }
                    .store(in: &self.cancellables)
            } else {
                // cancel button
                logger.info("else button")
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])

        if RBGuileBridge.guile_handle_key(keycode: event.keyCode,
                                          control: flags.contains(.control),
                                          command: flags.contains(.command),
                                          alt: flags.contains(.option),
                                          shift: flags.contains(.shift)) {
            // If a key is bound in a Guile script, that takes precedence, so we want to bail out here.  Otherwise, continue and execute the default "hard-coded" keybindings.
            return
        }

        if event.keyCode == kVK_Return
            && flags.isEmpty { // Enter/Return key
            enter()
        } else if event.keyCode == kVK_DownArrow       // down arrow
                    && flags == [.command] {
            moveSelectionDown()
        } else if event.keyCode == kVK_UpArrow       // up arrow
                    && flags == [.command] {
            moveSelectionUp()
        } else {
            super.keyDown(with: event)
        }
    }
}
