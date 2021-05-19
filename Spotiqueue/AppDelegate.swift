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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var searchField: NSSearchFieldCell!
    @IBOutlet weak var window: NSWindow!

    // Hooking up the Array Controller it was helpful to read     https://swiftrien.blogspot.com/2015/11/swift-example-binding-nstableview-to.html
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

    private var cancellables = Set<AnyCancellable>()

    @objc func handleURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        if let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding {
            if path.hasPrefix("spotiqueue://callback/") {
                spotify.authorizationManager.requestAccessAndRefreshTokens(
                    redirectURIWithQuery: URL(string: path)!,
                    // Must match the code verifier that was used to generate the
                    // code challenge when creating the authorization URL.
                    codeVerifier: codeVerifier,
                    // Must match the value used when creating the authorization URL.
                    state: state
                )
                .sink(receiveCompletion: { completion in
                    switch completion {
                        case .finished:
                            print("successfully authorized")
                        case .failure(let error):
                            if let authError = error as? SpotifyAuthorizationError, authError.accessWasDenied {
                                print("The user denied the authorization request")
                            }
                            else {
                                print("couldn't authorize application: \(error)")
                            }
                    }
                })
                .store(in: &cancellables)
            } else {
                fatalError("Oops, I don't recognise that URL.")
            }
        }
    }

    @IBAction func searched(_ sender: NSSearchField) {
        let searchString = self.searchField.stringValue
        if searchString.isEmpty {
            return
        }

        searchResults.append(RBSpotifySongTableRow(songId: searchString))

    }

    var spotify: SpotifyAPI<AuthorizationCodeFlowPKCEManager>!
    var codeVerifier: String!
    var codeChallenge: String!
    var state: String!

    func initialiseSpotifyLibrary() {
        let client_id = RBSecrets.getSecret(s: .clientId)
        let client_secret = RBSecrets.getSecret(s: .clientSecret)
        spotify = SpotifyAPI(
            authorizationManager: AuthorizationCodeFlowPKCEManager(
                clientId: client_id,
                clientSecret: client_secret
            )
        )
        codeVerifier = String.randomURLSafe(length: 128)
        codeChallenge = codeVerifier.makeCodeChallenge()

        // optional, but strongly recommended
        state = String.randomURLSafe(length: 128)
        let authorizationURL = spotify.authorizationManager.makeAuthorizationURL(
            redirectURI: URL(string: "spotiqueue://callback")!,
            codeChallenge: codeChallenge,
            state: state,
            scopes: [
                .playlistModifyPrivate,
                .userModifyPlaybackState,
                .playlistReadCollaborative,
                .userReadPlaybackPosition
            ]
            )!
        NSLog("authorizationURL: %@", authorizationURL.description)
    }

}

