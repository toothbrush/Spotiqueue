//
//  AppDelegate.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import AppMover
import Cocoa
import Combine
import Sparkle
import SpotifyWebAPI
import Stenographer

#if DEBUG
let minimumLogPriorityLevel: SXPriorityLevel = .all
#else
let minimumLogPriorityLevel: SXPriorityLevel = .warning
#endif

let logger = SXLogger(endpoints: [
    SXConsoleEndpoint(minimumPriorityLevel: minimumLogPriorityLevel)
])

@_cdecl("player_update_hook")
public func player_update_hook(hook: StatusUpdate, position_ms: UInt32, duration_ms: UInt32) {
    logger.info("Hook spotiqueue-worker hook ==> \(hook.rawValue)")
    switch hook {
        case EndOfTrack:
            DispatchQueue.main.async{
                AppDelegate.appDelegate().playerState = .Stopped
                AppDelegate.appDelegate().position = 0
                AppDelegate.appDelegate().duration = 0
                AppDelegate.appDelegate().playNextQueuedTrack()
            }
        case Paused:
            DispatchQueue.main.async{
                AppDelegate.appDelegate().playerState = .Paused
                AppDelegate.appDelegate().position = Double(position_ms/1000)
                AppDelegate.appDelegate().duration = Double(duration_ms/1000)
            }
        case Playing:
            DispatchQueue.main.async{
                AppDelegate.appDelegate().playerState = .Playing
                AppDelegate.appDelegate().position = Double(position_ms/1000)
                AppDelegate.appDelegate().duration = Double(duration_ms/1000)
            }
        case Stopped:
            DispatchQueue.main.async{
                AppDelegate.appDelegate().playerState = .Stopped
                AppDelegate.appDelegate().position = 0
                AppDelegate.appDelegate().duration = 0
            }
        case TimeToPreloadNextTrack:
            DispatchQueue.main.async{
                AppDelegate.appDelegate().preloadNextQueuedTrack()
            }
        default:
            fatalError("Received absurd hook.")
    }
}

enum PlayerState {
    case Stopped
    case Playing
    case Paused
}

enum LastSearch {
    case Freetext
    case Album
    case Artist
    case AllPlaylists
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBAction func checkForUpdates(_ sender: Any) {
        sparkle.checkForUpdates(sender)
    }

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
    @IBOutlet weak var queueHeaderLabel: NSTextField!
    @IBOutlet weak var albumImage: NSImageView!
    @IBOutlet weak var albumTitleLabel: NSTextField!
    @IBOutlet weak var songTitleLabel: NSTextField!
    @IBOutlet weak var durationLabel: NSTextField!
    @IBOutlet weak var saveSongButton: NSButton!
    @IBOutlet weak var searchSpinner: NSProgressIndicator!
    @IBOutlet weak var progressBar: NSProgressIndicator!

    var playerState: PlayerState = .Stopped
    var lastSearch: LastSearch = .Freetext

    var loginWindow: RBLoginWindow?

    let sparkle: SUUpdater = SUUpdater(for: Bundle.main)

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

    var position: TimeInterval = 0
    var duration: TimeInterval = 0

    func updateDurationDisplay() {
        let remaining = round(duration) - round(position)
        durationLabel.cell?.title = String(format: "%@ / -%@ / %@",
                                           round(position).positionalTime,
                                           round(remaining).positionalTime,
                                           round(duration).positionalTime)
        progressBar.isHidden = duration == 0
        progressBar.doubleValue = 100 * position/duration
    }

    // MARK: Button action bindings
    @IBAction func saveSongButtonPressed(_ sender: Any) {
        guard let _ = currentSong else {
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
        loginWindow = RBLoginWindow(windowNibName: "RBLoginWindow")
        if let window = loginWindow?.window {
            self.window?.beginSheet(window, completionHandler: { [self] response in
                self.initialiseSpotifyWebAPI()
                self.loginWindow = nil
            })
            loginWindow?.startLoginRoutine()
        } else {
            // Mind you, this will be nil if AppMover moves the executable away before we have had a chance to load the NIB.  Which is still a file...
            logger.critical("Something very weird - modal.window is nil!")
        }
        set_callback(player_update_hook(hook: position_ms: duration_ms:))
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown /*, .systemDefined */], handler: localKeyShortcuts(event:))

        queueArrayController.selectsInsertedObjects = false
        searchResultsArrayController.selectsInsertedObjects = false

        let timerInterval : TimeInterval = 0.25
        Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] timer in
            if let s = self {
                if s.playerState == .Playing {
                    s.position += timerInterval
                }
                s.updateDurationDisplay()
            }
        }
        
        self.addObserver(self, forKeyPath: "queueArrayController.arrangedObjects", options: .new, context: nil)

        // setup "focus loop" / tab order
        self.window.initialFirstResponder = self.searchField
        self.searchField.nextKeyView = self.searchTableView
        self.searchTableView.nextKeyView = self.queueTableView
        self.queueTableView.nextKeyView = self.searchField
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath else { return }
        
        if keyPath == "queueArrayController.arrangedObjects" {
            // sum up the durations and put the info into the queue heading label
            if let queueTracks = queueArrayController.arrangedObjects as? [RBSpotifySongTableRow] {
                let totalLengthSeconds = queueTracks.map(\.durationSeconds).reduce(0, +)
                if totalLengthSeconds > 0 {
                    queueHeaderLabel.stringValue = String(format: "Queue (total: %@)", totalLengthSeconds.positionalTime)
                } else {
                    queueHeaderLabel.stringValue = "Queue"
                }
            } else {
                logger.info("\(keyPath): \(String(describing: change))")
            }
        }
    }

    func localKeyShortcuts(event: NSEvent) -> NSEvent? {
        logger.info("I saw an event! \(event.description)")
        if event.type == .keyDown {
            logger.info("keycode = \(event.keyCode), characters: >\(String(describing: event.characters))<")
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad])
        if flags == .command
            && event.characters == "f" {
            self.window.makeFirstResponder(searchField)
        } else if flags == .command
                    && event.characters == "l" {
            self.window.makeFirstResponder(searchField)
        } else if flags == .command
                    && event.characters == "q" {
            for window in NSApp.windows {
                window.close()
            }
            NSApp.terminate(self)
        } else if flags == .command
                    && event.characters == "o" {
            retrieveAllPlaylists()
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
        #if !DEBUG
        AppMover.moveIfNecessary()
        #endif
        
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
                    codeVerifier: RBSpotify.codeVerifier,
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
                    switch completion {
                    case .failure(let error):
                        logger.error("couldn't retrieve access and refresh tokens:\n\(error)")
                        if let authError = error as? SpotifyAuthorizationError,
                           authError.accessWasDenied {
                            logger.error("Authorisation request denied!")
                            let alert = NSAlert.init()
                            alert.messageText = "Authorisation denied!"
                            alert.informativeText = "Authorisation request denied."
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                        else {
                            logger.error("Couldn't authorise: \(error.localizedDescription)")
                            let alert = NSAlert.init()
                            alert.messageText = "Authorisation failed!"
                            alert.informativeText = "Authorisation request failed: \(error.localizedDescription)"
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    case .finished:
                        logger.info("Successfully received tokens from Spotify.")
                        let alert = NSAlert.init()
                        alert.messageText = "Authorised"
                        alert.informativeText = "Successfully authorised with Spotify.  You can safely close the web browser window."
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
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

    func retrieveAllPlaylists() {
        guard !self.isSearching else {
            return
        }
        searchResults = []
        searchResultsArrayController.sortDescriptors = []
        self.isSearching = true
        lastSearch = .AllPlaylists
        
        spotify.api.currentUserPlaylists()
            .extendPagesConcurrently(spotify.api)
            .collectAndSortByOffset()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.isSearching = false
                if case .failure(let error) = completion {
                    logger.error("couldn't retrieve playlists: \(error.localizedDescription)")
                }
            }
            , receiveValue: { playlists in
                for pl in playlists {
                    self.searchResults.append(RBSpotifySongTableRow(playlist: pl))
                }
                self.searchTableView.selectRow(row: 0)
            })
            .store(in: &cancellables)
        
        self.window.makeFirstResponder(searchTableView)
    }
    
    func diveDeeperOnRow(for row: RBSpotifySongTableRow) {
        guard !self.isSearching else {
            return
        }
        searchResults = []
        self.isSearching = true

        switch lastSearch {
        case .Freetext:
            albumTracks(for: row.spotify_album)
        case .Album:
            artistTracks(for: row.spotify_artist)
        case .Artist:
            albumTracks(for: row.spotify_album)
        case .AllPlaylists:
            searchPlaylistTracks(for: row.spotify_uri)
        }
        self.window.makeFirstResponder(searchTableView)
    }
    
    private func searchPlaylistTracks(for playlist_uri: String?) {
        guard let playlist_uri = playlist_uri else {
            logger.warning("Called with nil playlist URI!  Doing nothing.")
            return
        }
        
        // okay, so listing a playlist's tracks isn't strictly a free-text search, but mainly we use that to tell Spotiqueue that a followup "detail-browse" should get the album for a track, and the one after that should get the artist's entire library.
        lastSearch = .Freetext
        searchResultsArrayController.sortDescriptors = []

        loadPlaylistTracksInto(for: playlist_uri, in: .Search)
    }
    
    enum SongList {
        case Queue
        case Search
    }
    
    func loadPlaylistTracksInto(for playlist_uri: String?,
                                in target: SongList,
                                at_the_top: Bool = false,
                                and_then_advance: Bool = false) {
        guard let playlist_uri = playlist_uri else {
            logger.warning("Called with nil playlist URI!  Doing nothing.")
            return
        }
        
        spotify.api.playlistItems(playlist_uri)
            .extendPagesConcurrently(spotify.api)
            .collectAndSortByOffset()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: {completion in
                self.isSearching = false
                switch completion {
                    case .finished:
                        logger.info("finished loading playlist")
                    case .failure(let error):
                        logger.error("Couldn't load playlist: \(error.localizedDescription)")
                }
            },
            receiveValue: { items in
                var newRows: Array<RBSpotifySongTableRow> = []
                for playlistItemContainer in items {
                    if case .track(let track) = playlistItemContainer.item {
                        newRows.append(RBSpotifySongTableRow.init(track: track))
                    }
                }
                self.insertTracks(newRows: newRows,
                                  in: target,
                                  at_the_top: at_the_top,
                                  and_then_advance: and_then_advance)
            })
            .store(in: &cancellables)
    }
    
    func insertTracks(newRows: Array<RBSpotifySongTableRow>,
                      in target: SongList,
                      at_the_top: Bool = false,
                      and_then_advance: Bool = false) {
        switch target {
        case .Queue:
            let position = at_the_top ? 0 : self.queue.count
            self.queue.insert(contentsOf: newRows, at: position)
            self.queueTableView.selectRow(row: position)
        case .Search:
            let position = at_the_top ? 0 : self.searchResults.count
            self.searchResults.insert(contentsOf: newRows, at: position)
            self.searchTableView.selectRow(row: position)
        }

        if and_then_advance {
            self.playNextQueuedTrack()
        }
    }

    private func albumTracks(for album: Album?) {
        guard let album = album else {
            logger.warning("Called with nil album!  Doing nothing.")
            return
        }
        
        lastSearch = .Album
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
                        RBSpotifySongTableRow.init(track: t, album: album, artist: t.artists!.first!)
                    }
                    // append the new table rows to the full array
                    self.searchResults.append(contentsOf: newTableRows)
                }
            )
            .store(in: &cancellables)
    }

    var runningTasks: Int = 0 {
        didSet {
            if runningTasks == 0 {
                self.isSearching = false
            }
        }
    }

    private func artistTracks(for artist: Artist?) {
        guard let artist = artist else {
            logger.warning("Called with nil artist!  Doing nothing.")
            return
        }

        lastSearch = .Artist
        let dispatchGroup = DispatchGroup()

        var albumsReceived: [Album] = []
        dispatchGroup.enter()
        spotify.api.artistFullAlbums(artist.uri!)
            .sink(
                receiveCompletion: { completion in
                    dispatchGroup.leave()
                    switch completion {
                        case .finished:
                            logger.info("finished loading artists' albums")
                        case .failure(let error):
                            logger.error("Couldn't load artist's albums: \(error.localizedDescription)")
                    }
                },
                receiveValue: { albums in
                    albumsReceived += albums
                }
            )
            .store(in: &cancellables)
        dispatchGroup.wait()

        runningTasks = albumsReceived.count
        for album in albumsReceived {
            spotify.api.albumTracks(album.uri!, limit: 50)
                .extendPagesConcurrently(spotify.api)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { [self] completion in
                    runningTasks -= 1
                    switch completion {
                        case .finished:
                            logger.info("finished loading tracks for album \(album.name)")
                        case .failure(let error):
                            logger.error("Couldn't load album's tracks: \(error.localizedDescription)")
                    }
                },
                receiveValue: { tracksPage in
                    let simplifiedTracks = tracksPage.items
                    // create a new array of table rows from the page of simplified tracks
                    let newTableRows = simplifiedTracks.map{ t in
                        RBSpotifySongTableRow.init(track: t, album: album, artist: artist)
                    }
                    // append the new table rows to the full array
                    self.searchResults.append(contentsOf: newTableRows)
                    // after finishing we want the cursor at the top. however, the "streaming" results means some newer albums might have showed up later, pushing your selection down.
                    self.searchTableView.selectRow(row: 0)
                }
                )
                .store(in: &cancellables)
        }
    }

    @IBAction func search(_ sender: NSSearchField) {
        guard !self.isSearching else {
            return
        }

        let searchString = self.searchFieldCell.stringValue
        if searchString.isEmpty {
            return
        }
        logger.info("Searching for \"\(searchString)\"...")

        searchResults = []
        self.isSearching = true
        lastSearch = .Freetext

        // cheap and dirty way of saying "this many pages expected"
        runningTasks = 4
        for i in 0..<runningTasks {
            spotify.api.search(
                query: searchString,
                categories: [.track],
                limit: 50,
                offset: i * 50
            )
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { [self] completion in
                    runningTasks -= 1
                    if case .failure(let error) = completion {
                        logger.error("Couldn't perform search:")
                        logger.error(error.localizedDescription)
                    }
                },
                receiveValue: { [self] searchResultsReturn in
                    for result in searchResultsReturn.tracks?.items ?? [] {
                        searchResults.append(RBSpotifySongTableRow(track: result))
                    }
                    logger.info("[query \(i)] Received \(self.searchResults.count) tracks")
                    searchResultsArrayController.sortDescriptors = RBSpotifySongTableRow.trackSortDescriptors
                    searchResultsArrayController.rearrangeObjects()
                    searchTableView.selectRow(row: 0)
                }
            )
            .store(in: &cancellables)
        }
        self.window.makeFirstResponder(searchTableView)
    }

    func initialiseSpotifyWebAPI() {
        if !spotify.isAuthorized {
            spotify.authorize()
        }
    }

    func playOrPause() {
        switch self.playerState {
            case .Stopped:
                return
            case .Playing:
                spotiqueue_pause_playback()
            case .Paused:
                spotiqueue_unpause_playback()
        }
    }

    func playNextQueuedTrack() {
        guard let nextTrack = queue.first else {
            return
        }
        spotiqueue_play_track(nextTrack.spotify_uri)
        self.albumTitleLabel.cell?.title = nextTrack.album
        self.songTitleLabel.cell?.title = nextTrack.prettyTitle()

        self.currentSong = nextTrack
        // ehm awkward, attempting to get second largest image.
        if let image = nextTrack.album_image {
            self.albumImage.imageFromServerURL(image.url.absoluteString, placeHolder: nil)
        }
        queue.remove(at: 0)
    }

    func preloadNextQueuedTrack() {
        guard let nextTrack = queue.first else {
            return
        }
        spotiqueue_preload_track(nextTrack.spotify_uri)
    }

    // Helper to give me a pointer to this AppDelegate object.
    static func appDelegate() -> AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
}
