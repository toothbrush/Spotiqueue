//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBTableView: NSTableView {
    func selectRow(row: Int) {
        if !(0..<self.numberOfRows).contains(row) {
            return
        }
        self.scrollRowToVisible(row)
        self.selectRowIndexes(IndexSet(integer: row),
                              byExtendingSelection: false)
    }

    func selectNext() {
        guard selectedRowIndexes.count == 1 else {
            return
        }
        selectRow(row: self.selectedRow + 1)
    }

    func selectPrev() {
        guard selectedRowIndexes.count == 1 else {
            return
        }
        selectRow(row: self.selectedRow - 1)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.characters == "j"
                    && flags.isEmpty {
            selectNext()
        } else if event.characters == "k"
                    && flags.isEmpty {
            selectPrev()
        } else {
            logger.info("Unrecognised key: \(event.keyCode)")
            super.keyDown(with: event)
        }
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
}
