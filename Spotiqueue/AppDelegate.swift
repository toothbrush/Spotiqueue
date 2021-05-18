//
//  AppDelegate.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var searchField: NSSearchFieldCell!
    @IBOutlet weak var window: NSWindow!

    @objc dynamic var searchResults: Array<SpotifySongTableRow> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initialiseSpotifyLibrary()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func searched(_ sender: NSSearchField) {
        let searchString = self.searchField.stringValue
        if searchString.isEmpty {
            return
        }

        searchResults.append(SpotifySongTableRow(songId: searchString))

    }

    func initialiseSpotifyLibrary() {
        let client_id = Secrets.getSecret(s: .clientId)
        let client_secret = Secrets.getSecret(s: .clientSecret)

    }

}

