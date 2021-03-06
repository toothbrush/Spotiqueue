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

class RBSearchTableView: RBTableView {
    override func associatedArrayController() -> NSArrayController {
        AppDelegate.appDelegate().searchResultsArrayController
    }

    func enter() {
        guard !self.selectedSearchTracks().isEmpty else {
            NSSound.beep()
            return
        }
        self.enqueueSelection(at_the_top: true, and_then_advance: true)
    }

    func focusFilterField() {
        let filterField = AppDelegate.appDelegate().filterResultsField
        NSApplication.shared.windows.first?.makeFirstResponder(filterField)
    }

    func enqueueSelection(at_the_top: Bool = false, and_then_advance: Bool = false) {
        guard !self.selectedSearchTracks().isEmpty else {
            NSSound.beep()
            return
        }

        if self.selectedSearchTracks().allSatisfy({ $0.itemType == .Playlist }) {
            // let's say we can only enqueue one playlist at a time. it's a mess otherwise (among other issues, the fact that top-enqueueing batches of tracks is weird, and that this is an async call so the shortest playlist is added first).
            guard self.selectedSearchTracks().count == 1 else {
                NSSound.beep()
                return
            }
            AppDelegate.appDelegate().loadPlaylistTracksInto(for: self.selectedSearchTracks().first!.spotify_uri,
                                                             in: .Queue,
                                                             at_the_top: at_the_top,
                                                             and_then_advance: and_then_advance)
        } else if self.selectedSearchTracks().allSatisfy({ $0.itemType == .Track }) {
            AppDelegate.appDelegate().insertTracks(newRows: self.selectedSearchTracks(),
                                                   in: .Queue,
                                                   at: at_the_top ? 0 : AppDelegate.appDelegate().queue.endIndex,
                                                   and_then_advance: and_then_advance)
        }
    }

    override func keyDown(with event: NSEvent) {
        // OMGWOW it took me a long time to figure out that arrow keys are special.  They count as both "function" and "numeric" keys. facepalm!
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])

        if RBGuileBridge.guile_handle_key(map: .search,
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
        } else if event.keyCode == kVK_LeftArrow, // cmd-shift-left arrow
                  flags == [.command, .shift]
        {
            self.enqueueSelection(at_the_top: true)
        } else if event.characters == "h", // cmd-shift-"h" key
                  flags == [.command, .shift]
        {
            self.enqueueSelection(at_the_top: true)
        } else if event.keyCode == kVK_LeftArrow, // cmd-left arrow
                  flags == .command
        {
            self.enqueueSelection()
        } else if event.characters == "h", // cmd-"h" key
                  flags == .command
        {
            self.enqueueSelection()
        } else if event.characters == "/",
                  flags.isEmpty
        {
            self.focusFilterField()
        } else if [kVK_Delete,
                   kVK_ForwardDelete,
                   kVK_ANSI_X,
                   kVK_ANSI_D].contains(Int(event.keyCode)),
            flags.isEmpty
        {
            self.attemptDeletePlaylist()
        } else if event.characters == "s", // cmd-s = save current queue as playlist
                  flags == [.command]
        {
            self.saveCurrentSearchResultsAsPlaylist()
        } else {
            super.keyDown(with: event)
        }
    }

    func attemptDeletePlaylist() {
        guard let lastSearch = AppDelegate.appDelegate().searchHistory.last else {
            // by definition if we've not yet searched, we can't be in "list playlists" mode.
            return
        }
        switch lastSearch {
            case .AllPlaylists:
                if self.selectedSearchTracks().count == 1,
                   let pl = self.selectedSearchTracks().first
                {
                    self.deletePlaylistWithConfirmation(playlist: pl)
                }
            default:
                return
        }
    }

    func deletePlaylistWithConfirmation(playlist: RBSpotifyItem) {
        let alert = NSAlert()
        alert.messageText = "Delete Playlist"
        alert.informativeText = "Are you sure you want to delete this playlist?"
        alert.alertStyle = NSAlert.Style.warning
        let font = NSFont.systemFont(ofSize: 20, weight: .bold)
        let attributes = [NSAttributedString.Key.font: font]
        let playlistNameField = NSTextField(labelWithAttributedString:
            NSAttributedString(string: playlist.title,
                               attributes: attributes))
        alert.accessoryView = playlistNameField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: AppDelegate.appDelegate().window) { result in
            if result == .alertFirstButtonReturn {
                // OK button. Clear the playlist from the view, first:
                // we can assume that one (1) playlist is highlighted, otherwise our ancestor-function wouldn't have called us.
                let selected_row = self.selectedRow
                AppDelegate.appDelegate().searchResults.removeAll { r in
                    r.spotify_uri == playlist.spotify_uri
                }
                self.selectRow(row: selected_row)
                // Now, actually ask Spotify to remove it.  Turns out Spotify's API doesn't have a real "delete" verb, you have to unfollow your own playlist.  Even if it's private 🤦‍♀️
                AppDelegate.appDelegate().spotify
                    .api
                    .unfollowPlaylistForCurrentUser(playlist.spotify_uri)
                    .sink { completion in
                        switch completion {
                            case .failure(let error):
                                logger.error("Couldn't unfollow playlist: \(error.localizedDescription)")
                            case .finished:
                                logger.info("Unfollowed playlist \(playlist.spotify_uri).")
                        }
                    }
                    .store(in: &self.cancellables)
            }
        }
    }

    func saveCurrentSearchResultsAsPlaylist() {
        guard !AppDelegate.appDelegate().searchResults.isEmpty else {
            // saving an empty queue makes no sense.
            return
        }
        let itemsToAddToPlaylist: [SpotifyURIConvertible] =
            AppDelegate.appDelegate().searchResults.map { track in
                track.spotify_uri
            }
        let suggestedName = String(format: "%@ – %@",
                                   AppDelegate.appDelegate().searchResults.first!.artist,
                                   AppDelegate.appDelegate().searchResults.first!.album)

        saveAsPlaylistWithConfirmation(suggestedName: suggestedName, messageText: "Save Search as Playlist", itemsToAddToPlaylist: itemsToAddToPlaylist)
    }

    func selectedSearchTracks() -> [RBSpotifyItem] {
        AppDelegate
            .appDelegate()
            .searchResultsArrayController
            .selectedObjects as? [RBSpotifyItem] ?? []
    }
}
