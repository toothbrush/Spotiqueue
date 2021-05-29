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

@_cdecl("player_update_hook")
public func player_update_hook(hook: StatusUpdate) {
    logger.info("Hook ==> \(hook.rawValue)")
    switch hook {
        case EndOfTrack:
            DispatchQueue.main.async{
                AppDelegate.appDelegate().playNextQueuedTrack()
            }
        default:
            logger.info("foo")
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var queueTableView: RBQueueTableView!
    @IBOutlet weak var searchTableView: RBSearchTableView!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var searchFieldCell: NSSearchFieldCell!
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var searchResultsArrayController: NSArrayController!
    @IBOutlet weak var queueArrayController: NSArrayController!

    @objc dynamic var searchResults: Array<RBSpotifySongTableRow> = []
    @objc dynamic var queue: Array<RBSpotifySongTableRow> = []

    // MARK: View element bindings
    @IBOutlet weak var albumImage: NSImageView!
    @IBOutlet weak var albumTitleLabel: NSTextField!
    @IBOutlet weak var songTitleLabel: NSTextField!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var saveSongButton: NSButton!
    @IBOutlet weak var searchSpinner: NSProgressIndicator!

    private var _isSearching: Bool = false
    var isSearching: Bool {
        get {
            return _isSearching
        }
        set {
            _isSearching = newValue
            if _isSearching {
                self.searchSpinner.isHidden = false
                self.searchSpinner.startAnimation(self)
            } else {
                self.searchSpinner.isHidden = true
                self.searchSpinner.stopAnimation(self)
            }
        }
    }

    // MARK: Button action bindings
    @IBAction func saveSongButtonPressed(_ sender: Any) {
        guard let song = currentSong else {
            return
        }
        // do complicated and potentially slow stuff here.
        // spotify.api.currentUserSavedTracks()
    }
    @IBAction func nextSongButtonPressed(_ sender: Any) {
        self.playNextQueuedTrack()
    }

    var spotify: RBSpotify = RBSpotify()
    var currentSong: RBSpotifySongTableRow?

    private var cancellables: Set<AnyCancellable> = []

    // Hooking up the Array Controller it was helpful to read https://swiftrien.blogspot.com/2015/11/swift-example-binding-nstableview-to.html
    // I also had to follow advice here https://stackoverflow.com/questions/46756535/xcode-cannot-resolve-the-entered-path-when-binding-control-in-xib-file because apparently in newer Swift, @objc dynamic isn't implied.
    // Here is another extensive howto around table views and such https://www.raywenderlich.com/921-cocoa-bindings-on-macos

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        initialiseSpotifyLibrary()
        set_callback(player_update_hook(hook:))
        spotiqueue_initialize_worker(RBSecrets.getSecret(s: .username),
                                     RBSecrets.getSecret(s: .password))
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { ev in
            self.eventSeen(event: ev)
        }

        self.window.makeFirstResponder(self.searchField)
        // setup "focus loop"
        self.searchField.nextKeyView = self.searchTableView;
        self.searchTableView.nextKeyView = self.queueTableView;
        self.queueTableView.nextKeyView = self.searchField;
    }

    func eventSeen(event:NSEvent) -> NSEvent? {
        logger.info("I saw an event! \(event.description)")
        logger.info("characters: >\(String(describing: event.characters))<")
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command)
            && event.characters == "f" {
            self.window.makeFirstResponder(searchField)
        } else if flags.contains(.command)
                    && event.characters == "l" {
            self.window.makeFirstResponder(searchField)
        } else {
            return event
        }
        return nil
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

    func loadTracksFromAlbum(for album: Album) {
        searchResults = []
        self.isSearching = true

        // retrieve album tracks
        spotify.api.albumTracks(
            album.uri!,
            limit: 50)
            .extendPages(spotify.api)
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { completion in
                    self.isSearching = false
                    switch completion {
                        case .finished:
                            logger.info("finished loading album object")
                        case .failure(let error):
                            logger.error("Couldn't load album: \(error.localizedDescription)")
                    }
                },
                receiveValue: { tracksPage in
                    let simplifiedTracks = tracksPage.items
                    // create a new array of table rows from the page of simplified tracks
                    let newTableRows = simplifiedTracks.map{ t in
                        RBSpotifySongTableRow.init(track: t, album: album)
                    }
                    // append the new table rows to the full array
                    self.searchResults.append(contentsOf: newTableRows)
                }
            )
            .store(in: &cancellables)
        self.window.makeFirstResponder(searchTableView)
    }

    @IBAction func search(_ sender: NSSearchField) {
        let searchString = self.searchFieldCell.stringValue
        if searchString.isEmpty {
            return
        }
        logger.info("Searching for \"\(searchString)\"...")

        searchResults = []
        self.isSearching = true
        spotify.api.search(
            query: searchString,
            categories: [.track],
            limit: 50
        )
        .receive(on: RunLoop.main)
        .sink(
            receiveCompletion: { [self] completion in
                self.isSearching = false
                if case .failure(let error) = completion {
                    logger.error("Couldn't perform search:")
                    logger.error(error.localizedDescription)
                }
            },
            receiveValue: { [self] searchResultsReturn in
                for result in searchResultsReturn.tracks?.items ?? [] {
                    searchResults.append(RBSpotifySongTableRow(track: result))
                }
                logger.info("Received \(self.searchResults.count) tracks")
                searchResultsArrayController.sortDescriptors = RBSpotifySongTableRow.trackSortDescriptors
                searchResultsArrayController.rearrangeObjects()
                searchTableView.selectRow(row: 0)
                self.isSearching = false
            }
        ).store(in: &cancellables)
        self.window.makeFirstResponder(searchTableView)
    }

    func initialiseSpotifyLibrary() {
        if !spotify.isAuthorized {
            spotify.authorize()
        }
    }

    func playNextQueuedTrack() {
        guard let nextTrack = queue.first else {
            return
        }
        spotiqueue_play_track(nextTrack.track_uri)
        self.albumTitleLabel.cell?.title = nextTrack.album
        self.songTitleLabel.cell?.title = String(format: "%@ — %@", nextTrack.artist, nextTrack.title)

        self.currentSong = nextTrack
        // ehm awkward, attempting to get second largest image.
        if let image = nextTrack.album_image {
            self.albumImage.imageFromServerURL(image.url, placeHolder: nil)
        }
        queue.remove(at: 0)
    }

    // Helper to give me a pointer to this AppDelegate object.
    static func appDelegate() -> AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
}
