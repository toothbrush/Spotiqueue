//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBQueueTableView: RBTableView {
    override func associatedArrayController() -> NSArrayController {
        AppDelegate.appDelegate().queueArrayController
    }

    func enter() {
        guard self.selectedRowIndexes.count == 1 else {
            logger.info("hmm, enter pressed on non-single track selection..")
            NSSound.beep()
            return
        }
        AppDelegate.appDelegate().queue.removeFirst(self.selectedRow)
        AppDelegate.appDelegate().playNextQueuedTrack()
    }

    func delete() {
        guard self.selectedRowIndexes.count > 0 else {
            NSSound.beep()
            return
        }
        let firstDeletionIdx = self.selectedRowIndexes.first!
        AppDelegate.appDelegate().queue.remove(atOffsets: self.selectedRowIndexes)
        self.selectRow(row: firstDeletionIdx)
    }

    override func searchForAlbum() {
        // rather a hack, but from the queue table we probably want to always to album browse, not artist browse if we've "toevallig" previously already done one on potentially an entire other track or artist.
        AppDelegate.appDelegate().lastSearch = .Freetext
        super.searchForAlbum()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])
        if event.keyCode == 36
            && flags.isEmpty { // Enter/Return key
            enter()
        } else if (event.keyCode == 51         // Backspace
                    || event.keyCode == 117   // Delete
                    || event.characters == "d")
                    && flags.isEmpty {
            delete()
        } else {
            super.keyDown(with: event)
        }
    }
}
