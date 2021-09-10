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

    func browseDetailsOnRow() {
        guard selectedRowIndexes.count == 1 else {
            NSSound.beep()
            return
        }
        if let songRow: RBSpotifySong = self.associatedArrayController().selectedObjects.first as? RBSpotifySong {
            AppDelegate.appDelegate().browseDetails(for: songRow)
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

    @objc func copy(_ sender: AnyObject?) {
        // https://bluelemonbits.com/2016/08/02/copy-one-or-multiple-nstableview-rows-swift/
        var copyTrackInsteadOfAlbum = true
        var previousValue = ""
        if let trigger = sender as? NSMenuItem {
            if trigger.title.contains("album") {
                copyTrackInsteadOfAlbum = false
            }
        }
        var copiedItems: [String] = []
        for obj in self.associatedArrayController().selectedObjects as? [RBSpotifySong] ?? [] {
            let copyText = copyTrackInsteadOfAlbum ?
                obj.copyTextTrack() :
                obj.copyTextAlbum()
            // avoid very obvious duplicates, e.g. when copying album link having selected many tracks from the same album
            if !copyText.isEmpty && copyText != previousValue {
                copiedItems.append(copyText)
            }
            previousValue = copyText
        }
        let pasteBoard = NSPasteboard.general
        if !copiedItems.isEmpty {
            pasteBoard.clearContents()
            pasteBoard.setString(copiedItems.joined(separator: "\n"), forType: NSPasteboard.PasteboardType.string)
        }
    }
    
    // Curious about keyCode values? See https://stackoverflow.com/questions/2080312/where-can-i-find-a-list-of-key-codes-for-use-with-cocoas-nsevent-class
    //
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
                                             keyCode: UInt16(kVK_DownArrow))!
            self.keyDown(with: synthetic)
        } else if event.characters?.lowercased() == "k" {
            let synthetic = NSEvent.keyEvent(with: .keyDown,
                                             location: .zero,
                                             modifierFlags: event.modifierFlags.union([.function, .numericPad]),
                                             timestamp: 0, windowNumber: 0,
                                             context: nil,
                                             characters: "",
                                             charactersIgnoringModifiers: "",
                                             isARepeat: event.isARepeat,
                                             keyCode: UInt16(kVK_UpArrow))!
            self.keyDown(with: synthetic)
        } else if event.characters == "g"
                    && flags.isEmpty {
            selectRow(row: 0)
        } else if event.characters == "G"
                    && flags == .shift {
            selectRow(row: self.numberOfRows - 1)
        } else if event.keyCode == kVK_Home
                    && flags.isEmpty {
            self.selectRow(row: 0)
        } else if event.keyCode == kVK_End
                    && flags.isEmpty {
            self.selectRow(row: numberOfRows - 1)
        } else if flags.isEmpty
                    && event.keyCode == kVK_LeftArrow { // left arrow
            focusQueue()
        } else if flags.isEmpty
                    && event.keyCode == kVK_RightArrow { // right arrow
            focusSearchResults()
        } else if event.characters == "h"
                    && flags.isEmpty { // "h" key, left
            focusQueue()
        } else if event.characters == "l"
                    && flags.isEmpty { // "l" key, right
            focusSearchResults()
        } else if flags == .command
                    && event.keyCode == kVK_RightArrow { // cmd-right, search for album
            browseDetailsOnRow()
        } else if flags == .command
                    && event.characters == ";" { // cmd-;, search for album, because cmd-L is taken?
            browseDetailsOnRow()
        } else if event.characters == " "
                    && flags.isEmpty {
            AppDelegate.appDelegate().playOrPause(self)
        } else if event.keyCode == kVK_PageUp
                    && flags.isEmpty {
            self.selectRow(row: selectedRow - nbVisibleRows() + 1)
        } else if event.keyCode == kVK_PageDown
                    && flags.isEmpty {
            self.selectRow(row: selectedRow + nbVisibleRows() - 1)
        } else if event.charactersIgnoringModifiers == "b"
                    && flags == [.control] {
            self.selectRow(row: selectedRow - nbVisibleRows() + 1)
        } else if event.charactersIgnoringModifiers == "f"
                    && flags == [.control] {
            self.selectRow(row: selectedRow + nbVisibleRows() - 1)
        } else if event.charactersIgnoringModifiers == "u"
                    && flags == [.control] {
            self.selectRow(row: selectedRow - nbVisibleRows()/2 + 1)
        } else if event.charactersIgnoringModifiers == "d"
                    && flags == [.control] {
            self.selectRow(row: selectedRow + nbVisibleRows()/2 - 1)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // return the number of visible rows
    func nbVisibleRows() -> Int {
        // minus 1, because of header row
        return Int(superview!.frame.size.height / rowHeight) - 1
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
