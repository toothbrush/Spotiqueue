//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBSearchTableView: RBTableView {

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
        } else {
            super.keyDown(with: event)
        }
    }

    func selectedSearchTracks() -> [RBSpotifySong] {
        return AppDelegate
            .appDelegate()
            .searchResultsArrayController
            .selectedObjects as? [RBSpotifySong] ?? []
    }
}
