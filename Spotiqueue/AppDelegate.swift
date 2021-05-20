//
//  AppDelegate.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import SpotifyWebAPI
import Combine
import Stenographer

let logger = SXLogger()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var searchField: NSSearchFieldCell!
    @IBOutlet weak var window: NSWindow!

    var spotify: RBSpotify = RBSpotify()

    private var cancellables: Set<AnyCancellable> = []

    // Hooking up the Array Controller it was helpful to read https://swiftrien.blogspot.com/2015/11/swift-example-binding-nstableview-to.html
    // I also had to follow advice here https://stackoverflow.com/questions/46756535/xcode-cannot-resolve-the-entered-path-when-binding-control-in-xib-file because apparently in newer Swift, @objc dynamic isn't implied.
    // Here is another extensive howto around table views and such https://www.raywenderlich.com/921-cocoa-bindings-on-macos

    @objc dynamic var searchResults: Array<RBSpotifySongTableRow> = []

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
        if let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding {
            if url.hasPrefix(RBSpotify.loginCallbackURL.description) {
                logger.info("received redirect from Spotify: '\(url)'")
                // This property is used to display an activity indicator in
                // `LoginView` indicating that the access and refresh tokens
                // are being retrieved.
                spotify.isRetrievingTokens = true

                // Complete the authorization process by requesting the
                // access and refresh tokens.
                spotify.api.authorizationManager.requestAccessAndRefreshTokens(
                    redirectURIWithQuery: URL(string: url)!,
                    // This value must be the same as the one used to create the
                    // authorization URL. Otherwise, an error will be thrown.
                    state: spotify.authorizationState
                )
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    // Whether the request succeeded or not, we need to remove
                    // the activity indicator.
                    self.spotify.isRetrievingTokens = false

                    /*
                     After the access and refresh tokens are retrieved,
                     `SpotifyAPI.authorizationManagerDidChange` will emit a
                     signal, causing `Spotify.handleChangesToAuthorizationManager()`
                     to be called, which will dismiss the loginView if the app was
                     successfully authorized by setting the
                     @Published `Spotify.isAuthorized` property to `true`.

                     The only thing we need to do here is handle the error and
                     show it to the user if one was received.
                     */
                    if case .failure(let error) = completion {
                        logger.error("couldn't retrieve access and refresh tokens:\n\(error)")
                        if let authError = error as? SpotifyAuthorizationError,
                           authError.accessWasDenied {
                            logger.error("Authorisation request denied!")
                        }
                        else {
                            logger.error("Couldn't Authorization With Your Account")
                        }
                    }
                })
                .store(in: &cancellables)

                // MARK: IMPORTANT: generate a new value for the state parameter
                // MARK: after each authorization request. This ensures an incoming
                // MARK: redirect from Spotify was the result of a request made by
                // MARK: this app, and not an attacker.
                self.spotify.authorizationState = String.randomURLSafe(length: 128)
            } else {
                logger.error("not handling URL: unexpected scheme: '\(url)'")
            }
        }
    }

    @IBAction func search(_ sender: NSSearchField) {
        let searchString = self.searchField.stringValue
        if searchString.isEmpty {
            return
        }
        logger.info("Searching for \"\(searchString)\"...")

        searchResults = []
        // self.isSearching = true
        spotify.api.search(
            query: searchString,
            categories: [.track],
            limit: 50
        )
        .receive(on: RunLoop.main)
        .sink(
            receiveCompletion: { completion in
                //self.isSearching = false
                logger.info("receiveCompletion")
                if case .failure(let error) = completion {
                    logger.error("Couldn't perform search:")
                    logger.error(error.localizedDescription)
                }
            },
            receiveValue: { [self] searchResultsReturn in
                logger.info("receiveValue")
                for result in searchResultsReturn.tracks?.items ?? [] {
                    searchResults.append(RBSpotifySongTableRow(track: result))
                }
                logger.info("Received \(self.searchResults.count) tracks")
            }
        ).store(in: &cancellables)
    }

    func initialiseSpotifyLibrary() {
        if !spotify.isAuthorized {
            spotify.authorize()
        }
    }
}

