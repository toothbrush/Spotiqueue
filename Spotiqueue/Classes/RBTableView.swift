//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBTableView: NSTableView {
    func associatedArrayController() -> NSArrayController {
        preconditionFailure("This method must be overridden")
    }

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

    func searchForAlbum() {
        guard selectedRowIndexes.count == 1 else {
            return
        }
        if let songRow: RBSpotifySongTableRow = self.associatedArrayController().selectedObjects.first as? RBSpotifySongTableRow {
            AppDelegate.appDelegate().diveDeeperOnRow(for: songRow)
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

    func focusSearchField() {
        let searchField = AppDelegate.appDelegate().searchField
        NSApplication.shared.windows.first?.makeFirstResponder(searchField)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.characters == "j"
                    && flags.isEmpty {
            selectNext()
        } else if event.characters == "k"
                    && flags.isEmpty {
            selectPrev()
        } else if event.characters == "g"
                    && flags.isEmpty {
            selectRow(row: 0)
        } else if event.characters == "G"
                    && flags.union(.shift) == .shift {
            selectRow(row: self.numberOfRows - 1)
        } else if flags.isDisjoint(with: NSEvent.ModifierFlags.command.union(.shift))
                    && event.keyCode == 123 { // left arrow
            focusQueue()
        } else if flags.isDisjoint(with: NSEvent.ModifierFlags.command.union(.shift))
                    && event.keyCode == 124 { // right arrow
            focusSearchResults()
        } else if event.keyCode == 4 { // "h" key, left
            focusQueue()
        } else if event.keyCode == 37 { // "l" key, right
            focusSearchResults()
        } else if flags.isSuperset(of: .command)
                    && event.keyCode == 124 { // cmd-right, search for album
            searchForAlbum()
        } else if flags.isSuperset(of: .command)
                    && event.characters == ";" { // cmd-;, search for album, because cmd-L is taken?
            searchForAlbum()
        } else if event.characters == "/"
                    && flags.isEmpty {
            focusSearchField()
        } else if event.characters == " "
                    && flags.isEmpty {
            AppDelegate.appDelegate().playOrPause()
        } else {
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
