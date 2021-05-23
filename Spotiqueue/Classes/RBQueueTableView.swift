//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBQueueTableView: RBTableView {
    func enter() {
        guard self.selectedRowIndexes.count == 1 else {
            logger.info("hmm, enter pressed on non-single track selection..")
            return
        }
        AppDelegate.appDelegate().queue.removeFirst(self.selectedRow)
        AppDelegate.appDelegate().playNextQueuedTrack()
    }

    override func keyDown(with event: NSEvent) {
        //let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 { // Enter/Return key
            enter()
        } else {
            logger.info("Unrecognised key: \(event.keyCode)")
            super.keyDown(with: event)
        }
    }
}
