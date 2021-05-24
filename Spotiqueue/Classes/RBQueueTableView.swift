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

    func delete() {
        guard self.selectedRowIndexes.count > 0 else {
            return
        }
        let firstDeletionIdx = self.selectedRowIndexes.first!
        AppDelegate.appDelegate().queue.remove(atOffsets: self.selectedRowIndexes)
        self.selectRow(row: firstDeletionIdx)
    }

    override func keyDown(with event: NSEvent) {
        //let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 { // Enter/Return key
            enter()
        } else if event.keyCode == 51         // Backspace
                    || event.keyCode == 117 { // Delete
            delete()
        } else {
            logger.info("Unrecognised key: \(event.keyCode)")
            super.keyDown(with: event)
        }
    }
}
