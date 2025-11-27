//
//  RBLoginWindow.swift
//  Spotiqueue
//
//  Created by paul david on 14/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBLoginWindow: NSWindowController {
    @IBOutlet var loginButton: NSButton!
    @IBOutlet var quitButton: NSButton!
    @IBOutlet var loginSpinner: NSProgressIndicator!

    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = "Login to Spotify"
    }

    @IBAction func loginPressed(_ sender: Any) {
        self.loginButton.isEnabled = false
        self.loginSpinner.isHidden = false
        self.loginSpinner.startAnimation(self)
        AppDelegate.appDelegate().spotify.authorize()
    }

    @IBAction func quitButton(_ sender: Any) {
        for window in NSApp.windows {
            window.close()
        }
        NSApp.terminate(self)
    }
}
