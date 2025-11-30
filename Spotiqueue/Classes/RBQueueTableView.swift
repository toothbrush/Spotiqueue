//
//  RBQueueTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import Combine
import SpotifyWebAPI

class RBQueueTableView: RBTableView {
    override func associatedArrayController() -> NSArrayController {
        AppDelegate.appDelegate().queueArrayController
    }

    @objc func paste(_ sender: AnyObject?) {
        AppDelegate.appDelegate().isSearching = true
        guard let contents: String = NSPasteboard.general.pasteboardItems?.first?.string(forType: .string) else {
            NSSound.beep()
            logger.error("Paste only works with strings.")
            AppDelegate.appDelegate().isSearching = false
            return
        }
        self.insertURIsInQueue(contents, at: AppDelegate.appDelegate().queue.endIndex)
    }

    func insertURIsInQueue(_ contents: String, at: Int) {
        AppDelegate.appDelegate().isSearching = true
        let incoming_uris = RBSpotifyAPI.sanitiseIncomingURIBlob(pasted_blob: contents)
        guard !incoming_uris.isEmpty else {
            AppDelegate.appDelegate().isSearching = false
            return
        }

        if incoming_uris.allSatisfy({ $0.uri.hasPrefix("spotify:track:") }) {
            // we can use the fancy batching-fetch-tracks mechanism.
            var stub_tracks: [RBSpotifyItem] = []
            for s in incoming_uris {
                logger.info("Hydrating track \(s)")
                stub_tracks.append(
                    RBSpotifyItem(spotify_uri: s.uri)
                )
            }
            AppDelegate.appDelegate().queue.insert(contentsOf: stub_tracks, at: at)
            self.selectRow(row: at)

            AppDelegate.appDelegate().runningTasks = Int((Double(stub_tracks.count) / 50.0).rounded(.up))
            for chunk in stub_tracks.chunked(size: 50) {
                AppDelegate.appDelegate().spotify.api.tracks(chunk.map(\.spotify_uri))
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
            var currentPasteOffsetIdx = 0
            Publishers.mergeMappedRetainingOrder(incoming_uris,
                                                 mapTransform: { AppDelegate.appDelegate().spotify.api.dealWithUnknownSpotifyURI($0) })
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                          AppDelegate.appDelegate().isSearching = false
                          logger.info("completion: \(completion)")
                      },
                      receiveValue: { tracks in
                          AppDelegate.appDelegate()
                              .insertTracks(newRows: tracks.joined().map { RBSpotifyItem(track: $0) },
                                            in: .Queue,
                                            at: at + currentPasteOffsetIdx,
                                            and_then_advance: false)
                          currentPasteOffsetIdx += tracks.joined().count
                          self.selectRow(row: at)
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
        _ = AppDelegate.appDelegate().playNextQueuedTrack(autoplay: true, position_ms: .zero)
        selectRow(row: 0)
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
        guard selectedRowIndexes.count == 1 else {
            NSSound.beep()
            return
        }

        if let trackRow: RBSpotifyItem = self.associatedArrayController().selectedObjects.first as? RBSpotifyItem {
            AppDelegate.appDelegate().browseDetails(for: trackRow, consideringHistory: false)
        }
    }

    // Number of rows of context to keep visible above/below selection when moving tracks
    private let scrollBuffer = 2

    func moveSelectedTracksUp() {
        guard !self.selectedRowIndexes.isEmpty else {
            NSSound.beep()
            return
        }
        if let first = self.selectedRowIndexes.first, first > 0 {
            let count = self.selectedRowIndexes.count
            // Moving up by 1: new position is one less than current first
            let newFirst = first - 1
            AppDelegate.appDelegate().queue.move(fromOffsets: self.selectedRowIndexes, toOffset: newFirst)
            // Explicitly set selection to new positions (move() makes them contiguous)
            let newSelection = IndexSet(integersIn: newFirst..<(newFirst + count))
            self.selectRowIndexes(newSelection, byExtendingSelection: false)
            // Scroll to show scrollBuffer rows above the selection for context.
            // We subtract from newFirst because we're moving up, so context is above.
            self.scrollRowToVisible((newFirst - scrollBuffer).clamped(fromInclusive: 0, toInclusive: self.numberOfRows - 1))
        }
    }

    func moveSelectedTracksDown() {
        guard !self.selectedRowIndexes.isEmpty else {
            NSSound.beep()
            return
        }
        if let first = self.selectedRowIndexes.first,
           let last = self.selectedRowIndexes.last,
           last + 1 < self.numberOfRows
        {
            let count = self.selectedRowIndexes.count
            // move(toOffset:) inserts BEFORE the given index, so to move down by 1,
            // we need toOffset = last + 2 (one past where the last item will land)
            AppDelegate.appDelegate().queue.move(fromOffsets: self.selectedRowIndexes, toOffset: last + 2)
            // After move(), items are contiguous starting at first + 1
            let newFirst = first + 1
            let newLast = newFirst + count - 1
            let newSelection = IndexSet(integersIn: newFirst..<(newFirst + count))
            self.selectRowIndexes(newSelection, byExtendingSelection: false)
            // Scroll to show scrollBuffer rows below the selection for context.
            // We add to newLast because we're moving down, so context is below.
            self.scrollRowToVisible((newLast + scrollBuffer).clamped(fromInclusive: 0, toInclusive: self.numberOfRows - 1))
        }
    }

    func saveCurrentQueueAsPlaylist() {
        guard !AppDelegate.appDelegate().queue.isEmpty else {
            // saving an empty queue makes no sense.
            return
        }
        let itemsToAddToPlaylist: [SpotifyURIConvertible] =
            AppDelegate.appDelegate().queue.map { track in
                track.spotify_uri
            }
        let suggestedName = String(format: "%@ – %@",
                                   AppDelegate.appDelegate().queue.first!.artist,
                                   AppDelegate.appDelegate().queue.first!.album)

        saveAsPlaylistWithConfirmation(suggestedName: suggestedName, messageText: "Save Queue as Playlist", itemsToAddToPlaylist: itemsToAddToPlaylist)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])

        if RBGuileBridge.guile_handle_key(map: .queue,
                                          keycode: event.keyCode,
                                          control: flags.contains(.control),
                                          command: flags.contains(.command),
                                          alt: flags.contains(.option),
                                          shift: flags.contains(.shift))
        {
            // If a key is bound in a Guile script, that takes precedence, so we want to bail out here.  Otherwise, continue and execute the default "hard-coded" keybindings.
            return
        }

        if event.keyCode == kVK_Return,
           flags.isEmpty
        { // Enter/Return key
            self.enter()
        } else if event.keyCode == kVK_DownArrow, // down arrow
                  flags == [.command]
        {
            self.moveSelectedTracksDown()
        } else if event.keyCode == kVK_UpArrow, // up arrow
                  flags == [.command]
        {
            self.moveSelectedTracksUp()
        } else if event.characters == "s", // cmd-s = save current queue as playlist
                  flags == [.command]
        {
            self.saveCurrentQueueAsPlaylist()
        } else {
            super.keyDown(with: event)
        }
    }
}
