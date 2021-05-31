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
            logger.info("hmm, enter pressed on empty search selection..")
            return
        }
        enqueueSelection(position: .Top)
        AppDelegate.appDelegate().playNextQueuedTrack()
    }

    func enqueueSelection(position: EnqueuePosition = .Bottom) {
        guard !selectedSearchTracks().isEmpty else {
            return
        }
        switch position {
            case .Bottom:
                AppDelegate.appDelegate().queue.append(contentsOf: self.selectedSearchTracks())
            case .Top:
                AppDelegate.appDelegate().queue = self.selectedSearchTracks() + AppDelegate.appDelegate().queue
        }
    }

    override func keyDown(with event: NSEvent) {
        // OMGWOW it took me a long time to figure out that arrow keys are special.  They count as both "function" and "numeric" keys. facepalm!
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])
                
        if event.keyCode == 36
            && flags.isEmpty { // Enter/Return key
            enter()
        } else if event.keyCode == 123 // cmd-shift-left arrow
                    && flags == [.command, .shift] {
            enqueueSelection(position: .Top)
        } else if event.characters == "h" // cmd-shift-"h" key
                    && flags == [.command, .shift] {
            enqueueSelection(position: .Top)
        } else if event.keyCode == 123 // cmd-left arrow
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
