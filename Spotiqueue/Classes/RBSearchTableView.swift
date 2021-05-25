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

    func enter() {
        guard !selectedSearchTracks().isEmpty else {
            logger.info("hmm, enter pressed on empty search selection..")
            return
        }
        AppDelegate.appDelegate().queue = self.selectedSearchTracks() + AppDelegate.appDelegate().queue
        AppDelegate.appDelegate().playNextQueuedTrack()
    }

    func enqueueSelection(position: EnqueuePosition = .Bottom) {
        guard !selectedSearchTracks().isEmpty else {
            return
        }
        AppDelegate.appDelegate().queue.append(contentsOf: self.selectedSearchTracks())
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 { // Enter/Return key
            enter()
        } else if event.keyCode == 123 // left arrow
                    && flags.contains(.command) {
            enqueueSelection()
        } else {
            logger.info("Unrecognised key: \(event.keyCode)")
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
