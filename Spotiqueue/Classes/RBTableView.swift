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

class RBTableView: NSTableView {
    var cancellables: Set<AnyCancellable> = []
    
    func associatedArrayController() -> NSArrayController {
        preconditionFailure("This method must be overridden")
    }
    
    func selectRow(row: Int) {
        let row_ = row.clamped(fromInclusive: 0, toInclusive: self.numberOfRows - 1)
        self.scrollRowToVisible(row_)
        self.selectRowIndexes(IndexSet(integer: row_),
                              byExtendingSelection: false)
    }
    
    func browseDetailsOnRow() {
        guard selectedRowIndexes.count == 1 else {
            NSSound.beep()
            return
        }
        if let trackRow: RBSpotifyTrack = self.associatedArrayController().selectedObjects.first as? RBSpotifyTrack {
            AppDelegate.appDelegate().browseDetails(for: trackRow)
        }
    }
    
    func focusQueue() {
        let queueTableView = AppDelegate.appDelegate().queueTableView
        NSApplication.shared.windows.first?.makeFirstResponder(queueTableView)
    }
    
    func focusSearchResults() {
        let searchTableView = AppDelegate.appDelegate().searchTableView
        NSApplication.shared.windows.first?.makeFirstResponder(searchTableView)
    }
    
    @objc func copy(_ sender: AnyObject?) {
        // https://bluelemonbits.com/2016/08/02/copy-one-or-multiple-nstableview-rows-swift/
        var copyTrackInsteadOfAlbum = true
        var previousValue = ""
        if let trigger = sender as? NSMenuItem {
            if trigger.title.contains("album") {
                copyTrackInsteadOfAlbum = false
            }
        }
        var copiedItems: [String] = []
        for obj in self.associatedArrayController().selectedObjects as? [RBSpotifyTrack] ?? [] {
            let copyText = copyTrackInsteadOfAlbum ?
                obj.copyTextTrack() :
                obj.copyTextAlbum()
            // avoid very obvious duplicates, e.g. when copying album link having selected many tracks from the same album
            if !copyText.isEmpty && copyText != previousValue {
                copiedItems.append(copyText)
            }
            previousValue = copyText
        }
        let pasteBoard = NSPasteboard.general
        if !copiedItems.isEmpty {
            pasteBoard.clearContents()
            pasteBoard.setString(copiedItems.joined(separator: "\n"), forType: NSPasteboard.PasteboardType.string)
            RBGuileBridge.selection_copied_hook(copied: copiedItems)
        }
    }
    
    // Curious about keyCode values? See https://stackoverflow.com/questions/2080312/where-can-i-find-a-list-of-key-codes-for-use-with-cocoas-nsevent-class
    //
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])
        if event.charactersIgnoringModifiers?.lowercased() == "j" {
            let synthetic = NSEvent.keyEvent(with: .keyDown,
                                             location: .zero,
                                             modifierFlags: event.modifierFlags.union([.function, .numericPad]),
                                             timestamp: 0, windowNumber: 0,
                                             context: nil,
                                             characters: "",
                                             charactersIgnoringModifiers: "",
                                             isARepeat: event.isARepeat,
                                             keyCode: UInt16(kVK_DownArrow))!
            self.keyDown(with: synthetic)
        } else if event.characters?.lowercased() == "k" {
            let synthetic = NSEvent.keyEvent(with: .keyDown,
                                             location: .zero,
                                             modifierFlags: event.modifierFlags.union([.function, .numericPad]),
                                             timestamp: 0, windowNumber: 0,
                                             context: nil,
                                             characters: "",
                                             charactersIgnoringModifiers: "",
                                             isARepeat: event.isARepeat,
                                             keyCode: UInt16(kVK_UpArrow))!
            self.keyDown(with: synthetic)
        } else if event.characters == "g"
                    && flags.isEmpty {
            selectRow(row: 0)
        } else if event.characters == "G"
                    && flags == .shift {
            selectRow(row: self.numberOfRows - 1)
        } else if event.keyCode == kVK_Home
                    && flags.isEmpty {
            self.selectRow(row: 0)
        } else if event.keyCode == kVK_End
                    && flags.isEmpty {
            self.selectRow(row: numberOfRows - 1)
        } else if flags.isEmpty
                    && event.keyCode == kVK_LeftArrow { // left arrow
            focusQueue()
        } else if flags.isEmpty
                    && event.keyCode == kVK_RightArrow { // right arrow
            focusSearchResults()
        } else if event.characters == "h"
                    && flags.isEmpty { // "h" key, left
            focusQueue()
        } else if event.characters == "l"
                    && flags.isEmpty { // "l" key, right
            focusSearchResults()
        } else if flags == .command
                    && event.keyCode == kVK_RightArrow { // cmd-right, search for album
            browseDetailsOnRow()
        } else if flags == .command
                    && event.characters == ";" { // cmd-;, search for album, because cmd-L is taken?
            browseDetailsOnRow()
        } else if event.characters == " "
                    && flags.isEmpty {
            AppDelegate.appDelegate().playOrPause(self)
        } else if event.keyCode == kVK_PageUp
                    && flags.isEmpty {
            self.selectRow(row: selectedRow - nbVisibleRows() + 1)
        } else if event.keyCode == kVK_PageDown
                    && flags.isEmpty {
            self.selectRow(row: selectedRow + nbVisibleRows() - 1)
        } else if event.charactersIgnoringModifiers == "b"
                    && flags == [.control] {
            self.selectRow(row: selectedRow - nbVisibleRows() + 1)
        } else if event.charactersIgnoringModifiers == "f"
                    && flags == [.control] {
            self.selectRow(row: selectedRow + nbVisibleRows() - 1)
        } else if event.charactersIgnoringModifiers == "u"
                    && flags == [.control] {
            self.selectRow(row: selectedRow - nbVisibleRows()/2 + 1)
        } else if event.charactersIgnoringModifiers == "d"
                    && flags == [.control] {
            self.selectRow(row: selectedRow + nbVisibleRows()/2 - 1)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // return the number of visible rows
    func nbVisibleRows() -> Int {
        // minus 1, because of header row
        return Int(superview!.frame.size.height / rowHeight) - 1
    }
    
    override func resignFirstResponder() -> Bool {
        self.backgroundColor = NSColor.white
        return super.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        self.backgroundColor = NSColor(srgbRed: 187.0/255.0,
                                       green: 202.0/255.0,
                                       blue: 1.0,
                                       alpha: 0.4)
        return super.becomeFirstResponder()
    }
    
    private let ADD_TO_PLAYLIST_CHUNKSIZE: Int = 100 // The maximum supported by the Spotify API.
    /*
     It's not beautiful, but i had immense trouble with a) chunking a bunch of tracks and adding them one after the other to a playlist.  Using MergeMany still resulted in jumbled playlists, perhaps because the Spotify API doesn't like being hit that quickly in succession.  Anyway this "tail recursive" approach is a bit of an abomination (special callout for the 2s delay) but at least it's reliable.
     */
    func continueAddingItemsToNewPlaylist(spotify: RBSpotifyAPI,
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
                        self.continueAddingItemsToNewPlaylist(spotify: spotify,
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
    
    func createNewPlaylist(name: String, withItems itemsToAddToPlaylist: [SpotifyURIConvertible]) {
        guard !itemsToAddToPlaylist.isEmpty else {
            // saving an empty playlist makes no sense.
            logger.error("Not saving empty playlist <\(name)>!")
            return
        }
        
        let spotify = AppDelegate.appDelegate().spotify
        let details = PlaylistDetails(name: name,
                                      isPublic: false,
                                      isCollaborative: false,
                                      description:
                                        String(format: "%@ created by Spotiqueue", Date().string(format: "yyyy-MM-dd")))
        var createdPlaylistURI = ""
        spotify.api.createPlaylist(for: spotify.currentUser!.uri, details)
            .sink { completion in
                switch completion {
                    case .failure(let error):
                        logger.error("Couldn't create playlist: \(error.localizedDescription)")
                    case .finished:
                        logger.info("Done with playlist creation: \(createdPlaylistURI).")
                        self.continueAddingItemsToNewPlaylist(spotify: spotify,
                                                              playlist_uri: createdPlaylistURI,
                                                              items: itemsToAddToPlaylist)
                }
            } receiveValue: { playlist in
                createdPlaylistURI = playlist.uri
                logger.info("Created playlist, uri: \(createdPlaylistURI)")
            }
            .store(in: &self.cancellables)
    }

    func saveAsPlaylistWithConfirmation(suggestedName: String, messageText: String, itemsToAddToPlaylist: [SpotifyURIConvertible]) {
        guard !itemsToAddToPlaylist.isEmpty else {
            // saving an empty list makes no sense.
            return
        }
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = "Name for new playlist:"
        alert.alertStyle = NSAlert.Style.informational
        let playlistNameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        playlistNameField.stringValue = suggestedName
        alert.accessoryView = playlistNameField
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = playlistNameField
        alert.beginSheetModal(for: AppDelegate.appDelegate().window) { result in
            if result == .alertFirstButtonReturn {
                // OK button
                let playlistName = playlistNameField.stringValue.strip()
                self.createNewPlaylist(name: playlistName, withItems: itemsToAddToPlaylist)
            }
        }
    }
}
