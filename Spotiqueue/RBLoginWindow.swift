//
//  RBLoginWindow.swift
//  Spotiqueue
//
//  Created by paul david on 14/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//
//  NOTE: This file is deprecated and no longer used.
//  OAuth authentication is now handled via SpotifyWebAPI.
//  Keeping this file for reference only.

import Cocoa

class RBLoginWindow: NSWindowController {
    @IBOutlet var loginButton: NSButton!
    @IBOutlet var quitButton: NSButton!
    @IBOutlet var loginSpinner: NSProgressIndicator!

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    @IBAction func quitButton(_ sender: Any) {
        for window in NSApp.windows {
            window.close()
        }
        NSApp.terminate(self)
    }
}
