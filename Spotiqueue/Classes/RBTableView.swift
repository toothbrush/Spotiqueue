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
        let row_ = row.clamped(fromInclusive: 0, toInclusive: self.numberOfRows - 1)
        self.scrollRowToVisible(row_)
        self.selectRowIndexes(IndexSet(integer: row_),
                              byExtendingSelection: false)
    }

    func searchForAlbum() {
        guard selectedRowIndexes.count == 1 else {
            NSSound.beep()
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
                                             keyCode: 125)!
            super.keyDown(with: synthetic)
        } else if event.characters?.lowercased() == "k" {
            let synthetic = NSEvent.keyEvent(with: .keyDown,
                                             location: .zero,
                                             modifierFlags: event.modifierFlags.union([.function, .numericPad]),
                                             timestamp: 0, windowNumber: 0,
                                             context: nil,
                                             characters: "",
                                             charactersIgnoringModifiers: "",
                                             isARepeat: event.isARepeat,
                                             keyCode: 126)!
            super.keyDown(with: synthetic)
        } else if event.characters == "g"
                    && flags.isEmpty {
            selectRow(row: 0)
        } else if event.characters == "G"
                    && flags == .shift {
            selectRow(row: self.numberOfRows - 1)
        } else if flags.isEmpty
                    && event.keyCode == 123 { // left arrow
            focusQueue()
        } else if flags.isEmpty
                    && event.keyCode == 124 { // right arrow
            focusSearchResults()
        } else if event.keyCode == 4
                    && flags.isEmpty { // "h" key, left
            focusQueue()
        } else if event.keyCode == 37
                    && flags.isEmpty { // "l" key, right
            focusSearchResults()
        } else if flags == .command
                    && event.keyCode == 124 { // cmd-right, search for album
            searchForAlbum()
        } else if flags == .command
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
