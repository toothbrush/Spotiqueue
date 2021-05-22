//
//  RBSearchTableView.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBSearchTableView: NSTableView {

    // This enter() function is a prime candidate to put into a search- or queue-specific table subclass, maybe.
    func enter() {
        guard !selectedTracks().isEmpty else {
            logger.info("hmm, enter pressed on empty track selection..")
            return
        }

        if selectedTracks().count == 1 {
            logger.info("Attempt to play track: \(selectedTracks().first!)")
            logger.info(" -> that's track \(selectedTracks().first!.track.uri!)")
            spotiqueue_play_track(selectedTracks().first!.track.uri!)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // Enter/Return key
            enter()
        } else {
            super.keyDown(with: event)
        }
    }

    func selectedTracks() -> [RBSpotifySongTableRow] {
        var result: [RBSpotifySongTableRow] = []
        for r in selectedRowIndexes {
            let track = AppDelegate.appDelegate().searchResults[r]
            result.append(track)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        self.usesAlternatingRowBackgroundColors = true
        self.backgroundColor = NSColor.white
        return super.resignFirstResponder()
    }

    override func becomeFirstResponder() -> Bool {
        self.usesAlternatingRowBackgroundColors = false
        self.backgroundColor = NSColor(srgbRed: 187.0/255.0,
                                       green: 202.0/255.0,
                                       blue: 1.0,
                                       alpha: 0.4)
        return super.becomeFirstResponder()
    }
}
