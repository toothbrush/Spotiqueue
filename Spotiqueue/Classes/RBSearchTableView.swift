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
    var cancellables: Set<AnyCancellable> = []

    override func associatedArrayController() -> NSArrayController {
        AppDelegate.appDelegate().searchResultsArrayController
    }

    func enter() {
        guard !selectedSearchTracks().isEmpty else {
            NSSound.beep()
            return
        }
        enqueueSelection(at_the_top: true, and_then_advance: true)
    }

    func focusFilterField() {
        let filterField = AppDelegate.appDelegate().filterResultsField
        NSApplication.shared.windows.first?.makeFirstResponder(filterField)
    }

    func enqueueSelection(at_the_top: Bool = false, and_then_advance: Bool = false) {
        guard !selectedSearchTracks().isEmpty else {
            NSSound.beep()
            return
        }

        if selectedSearchTracks().allSatisfy({ $0.myKind == .Playlist }) {
            // let's say we can only enqueue one playlist at a time. it's a mess otherwise (among other issues, the fact that top-enqueueing batches of tracks is weird, and that this is an async call so the shortest playlist is added first).
            guard selectedSearchTracks().count == 1 else {
                NSSound.beep()
                return
            }
            AppDelegate.appDelegate().loadPlaylistTracksInto(for: selectedSearchTracks().first!.spotify_uri,
                                                             in: .Queue,
                                                             at_the_top: at_the_top,
                                                             and_then_advance: and_then_advance)
        } else if selectedSearchTracks().allSatisfy({ $0.myKind == .Track }) {
            AppDelegate.appDelegate().insertTracks(newRows: self.selectedSearchTracks(),
                                                   in: .Queue,
                                                   at_the_top: at_the_top,
                                                   and_then_advance: and_then_advance)
        }
    }

    override func keyDown(with event: NSEvent) {
        // OMGWOW it took me a long time to figure out that arrow keys are special.  They count as both "function" and "numeric" keys. facepalm!
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])
                
        if event.keyCode == kVK_Return
            && flags.isEmpty { // Enter/Return key
            enter()
        } else if event.keyCode == kVK_LeftArrow // cmd-shift-left arrow
                    && flags == [.command, .shift] {
            enqueueSelection(at_the_top: true)
        } else if event.characters == "h" // cmd-shift-"h" key
                    && flags == [.command, .shift] {
            enqueueSelection(at_the_top: true)
        } else if event.keyCode == kVK_LeftArrow // cmd-left arrow
                    && flags == .command {
            enqueueSelection()
        } else if event.characters == "h" // cmd-"h" key
                    && flags == .command {
            enqueueSelection()
        } else if event.characters == "/"
                    && flags.isEmpty {
            focusFilterField()
        } else if [kVK_Delete,
                   kVK_ForwardDelete,
                   kVK_ANSI_X,
                   kVK_ANSI_D].contains(Int(event.keyCode))
                    && flags.isEmpty {
            attemptDeletePlaylist()
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
                   let pl = self.selectedSearchTracks().first {
                    deletePlaylistWithConfirmation(playlist: pl)
                }
            default:
                return
        }
    }

    func deletePlaylistWithConfirmation(playlist: RBSpotifySong) {
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

    func selectedSearchTracks() -> [RBSpotifySong] {
        return AppDelegate
            .appDelegate()
            .searchResultsArrayController
            .selectedObjects as? [RBSpotifySong] ?? []
    }
}
