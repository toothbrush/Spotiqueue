//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBSearchTableView: RBTableView {
    enum EnqueuePosition {
        case Top
        case Bottom
    }

    override func associatedArrayController() -> NSArrayController {
        AppDelegate.appDelegate().searchResultsArrayController
    }

    func enter() {
        guard !selectedSearchTracks().isEmpty else {
            NSSound.beep()
            return
        }
        enqueueSelection(position: .Top, and_then_advance: true)
    }

    func enqueueSelection(position: EnqueuePosition = .Bottom, and_then_advance: Bool = false) {
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
                                                             at_the_top: position == .Top,
                                                             and_then_advance: and_then_advance)
        } else if selectedSearchTracks().allSatisfy({ $0.myKind == .Track }) {
            switch position {
                case .Bottom:
                    AppDelegate.appDelegate().queue.append(contentsOf: self.selectedSearchTracks())
                    AppDelegate.appDelegate().queueTableView.selectRow(row: AppDelegate.appDelegate().queue.count - self.selectedSearchTracks().count)
                case .Top:
                    AppDelegate.appDelegate().queue = self.selectedSearchTracks() + AppDelegate.appDelegate().queue
                    AppDelegate.appDelegate().queueTableView.selectRow(row: 0)
            }
            if and_then_advance {
                AppDelegate.appDelegate().playNextQueuedTrack()
            }
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
            enqueueSelection(position: .Top)
        } else if event.characters == "h" // cmd-shift-"h" key
                    && flags == [.command, .shift] {
            enqueueSelection(position: .Top)
        } else if event.keyCode == kVK_LeftArrow // cmd-left arrow
                    && flags == .command {
            enqueueSelection()
        } else if event.characters == "h" // cmd-"h" key
                    && flags == .command {
            enqueueSelection()
        } else {
            super.keyDown(with: event)
        }
    }

    func selectedSearchTracks() -> [RBSpotifySongTableRow] {
        return AppDelegate
            .appDelegate()
            .searchResultsArrayController
            .selectedObjects as? [RBSpotifySongTableRow] ?? []
    }
}
