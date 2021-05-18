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

    // Hooking up the Array Controller it was helpful to read     https://swiftrien.blogspot.com/2015/11/swift-example-binding-nstableview-to.html
    // I also had to follow advice here https://stackoverflow.com/questions/46756535/xcode-cannot-resolve-the-entered-path-when-binding-control-in-xib-file because apparently in newer Swift, @objc dynamic isn't implied.
    // Here is another extensive howto around table views and such https://www.raywenderlich.com/921-cocoa-bindings-on-macos

    @objc dynamic var searchResults: Array<SpotifySongTableRow> = []

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initialiseSpotifyLibrary()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // from https://stackoverflow.com/questions/1991072/how-to-handle-with-a-default-url-scheme
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager
            .shared()
            .setEventHandler(
                self,
                andSelector: #selector(handleURL(event:reply:)),
                forEventClass: AEEventClass(kInternetEventClass),
                andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        if let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding {
            NSLog("Opened URL: \(path)")
        }
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

