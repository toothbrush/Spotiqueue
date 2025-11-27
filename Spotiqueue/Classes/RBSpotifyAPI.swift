//
//  RBSpotify.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Combine
import Foundation
import SpotifyWebAPI
import SwiftUI

/**
 A helper class that wraps around an instance of `SpotifyAPI`
 and provides convenience methods for authorizing your application.

 Its most important role is to handle changes to the authorzation
 information and save them to persistent storage in the keychain.
 */
final class RBSpotifyAPI: ObservableObject {
    static func sanitiseIncomingURIBlob(pasted_blob: String) -> [SpotifyURIConvertible] {
        pasted_blob
            .split(whereSeparator: \.isNewline)
            .compactMap { $0
                .trimmingCharacters(in: .whitespaces)
                .split(whereSeparator: \.isWhitespace)
                .first
            }
            .compactMap { self.sanitiseIncomingURI(value: String($0)) }
    }

    static func sanitiseIncomingURI(value: String) -> String? {
        if value.hasPrefix("spotify:track:")
            || value.hasPrefix("spotify:playlist:")
            || value.hasPrefix("spotify:album:")
        {
            return value
        } else if value.hasPrefix("https://open.spotify.com/track/")
            || value.hasPrefix("https://open.spotify.com/playlist/")
            || value.hasPrefix("https://open.spotify.com/album/")
        {
            if let url = URL(string: value) {
                let my_uri = "spotify" + url.path.replacingOccurrences(of: "/", with: ":")
                logger.info("Converted open.spotify.com URL to \(my_uri)")
                return my_uri
            }
        }
        logger.warning("Ignoring invalid Spotify URI: \(value)")
        return nil
    }

    private static let clientId: String = "f925f1b4e9164425be3d9ec9bf4be1c5"

    /// The URL that Spotify will redirect to after the user either
    /// authorizes or denies authorization for your application.
    static let loginCallbackURL = URL(
        string: "spotiqueue://callback"
    )!

    /// A cryptographically-secure random string used to ensure
    /// than an incoming redirect from Spotify was the result of a request
    /// made by this app, and not an attacker. **This value is regenerated**
    /// **after each authorization process completes.**
    var authorizationState = String.randomURLSafe(length: 128)
    static let codeVerifier = String.randomURLSafe(length: 128)
    static let codeChallenge = String.makeCodeChallenge(codeVerifier: codeVerifier)
    /**
     Whether or not the application has been authorized. If `true`,
     then you can begin making requests to the Spotify web API
     using the `api` property of this class, which contains an instance
     of `SpotifyAPI`.

     When `false`, `LoginView` is presented, which prompts the user to
     login. When this is set to `true`, `LoginView` is dismissed.

     This property provides a convenient way for the user interface
     to be updated based on whether the user has logged in with their
     Spotify account yet. For example, you could use this property disable
     UI elements that require the user to be logged in.

     This property is updated by `handleChangesToAuthorizationManager()`,
     which is called every time the authorization information changes,
     and `authorizationManagerDidDeauthorize()`, which is called
     everytime `SpotifyAPI.authorizationManager.deauthorize()` is called.
     */
    @Published var isAuthorized = false

    /// If `true`, then the app is retrieving access and refresh tokens.
    /// Used by `LoginView` to present an activity indicator.
    @Published var isRetrievingTokens = false

    @Published var currentUser: SpotifyUser? = nil

    /// An instance of `SpotifyAPI` that you use to make requests to
    /// the Spotify web API.
    let api = SpotifyAPI(
        authorizationManager: AuthorizationCodeFlowPKCEManager(
            clientId: RBSpotifyAPI.clientId
        )
    )

    var cancellables: Set<AnyCancellable> = []

    // MARK: - Methods -

    init() {
        // Configure the loggers.
        self.api.apiRequestLogger.logLevel = .trace
        // self.api.logger.logLevel = .trace

        // MARK: Important: Subscribe to `authorizationManagerDidChange` BEFORE

        // MARK: retrieving `authorizationManager` from persistent storage

        self.api.authorizationManagerDidChange
            // We must receive on the main thread because we are
            // updating the @Published `isAuthorized` property.
            .receive(on: RunLoop.main)
            .sink(receiveValue: self.handleChangesToAuthorizationManager)
            .store(in: &self.cancellables)

        self.api.authorizationManagerDidDeauthorize
            .receive(on: RunLoop.main)
            .sink(receiveValue: self.authorizationManagerDidDeauthorize)
            .store(in: &self.cancellables)

        // MARK: Check to see if the authorization information is saved in

        // MARK: the keychain.

        if let authManagerData = RBSecrets.getSecret(s: .authorizationManager) {
            do {
                // Try to decode the data.
                let authorizationManager = try JSONDecoder().decode(
                    AuthorizationCodeFlowPKCEManager.self,
                    from: authManagerData.data(using: .utf8)!
                )
                logger.debug("found authorization information in keychain")

                /*
                 This assignment causes `authorizationManagerDidChange`
                 to emit a signal, meaning that
                 `handleChangesToAuthorizationManager()` will be called.

                 Note that if you had subscribed to
                 `authorizationManagerDidChange` after this line,
                 then `handleChangesToAuthorizationManager()` would not
                 have been called and the @Published `isAuthorized` property
                 would not have been properly updated.

                 We do not need to update `isAuthorized` here because it
                 is already done in `handleChangesToAuthorizationManager()`.
                 */
                self.api.authorizationManager = authorizationManager

            } catch {
                logger.error("could not decode authorizationManager from data:\n\(error)")
            }
        } else {
            logger.info("did NOT find authorization information in keychain")
        }
    }

    /**
     A convenience method that creates the authorization URL and opens it
     in the browser.

     You could also configure it to accept parameters for the authorization
     scopes.

     This is called when the user taps the "Log in with Spotify" button
     in `LoginView`.
     */
    func authorize() {
        let url = self.api.authorizationManager.makeAuthorizationURL(
            redirectURI: Self.loginCallbackURL,
            codeChallenge: RBSpotifyAPI.codeChallenge,
            // This same value **MUST** be provided for the state parameter of
            // `authorizationManager.requestAccessAndRefreshTokens(redirectURIWithQuery:state:)`.
            // Otherwise, an error will be thrown.
            state: authorizationState,
            scopes: [
                .streaming,
                .userReadPlaybackState,
                .userModifyPlaybackState,
                .playlistModifyPrivate,
                .playlistModifyPublic,
                .playlistReadPrivate,
                .playlistReadCollaborative,
                .userLibraryRead,
                .userLibraryModify,
                .userReadEmail,
            ]
        )!

        logger.debug("authorizationURL: \(url.description)")

        NSWorkspace.shared.open(url)
    }

    /**
     Saves changes to `api.authorizationManager` to the keychain.

     This method is called every time the authorization information changes. For
     example, when the access token gets automatically refreshed, (it expires after
     an hour) this method will be called.

     It will also be called after the access and refresh tokens are retrieved using
     `requestAccessAndRefreshTokens(redirectURIWithQuery:state:)`.

     Read the full documentation for [SpotifyAPI.authorizationManagerDidChange][1].

     [1]: https://peter-schorn.github.io/SpotifyAPI/Classes/SpotifyAPI.html#/s:13SpotifyWebAPI0aC0C29authorizationManagerDidChange7Combine18PassthroughSubjectCyyts5NeverOGvp
     */
    func handleChangesToAuthorizationManager() {
//        withAnimation(LoginView.animation) {
//            // Update the @Published `isAuthorized` property.
//            // When set to `true`, `LoginView` is dismissed, allowing the
//            // user to interact with the rest of the app.
//            self.isAuthorized = self.api.authorizationManager.isAuthorized()
//        }

        self.isAuthorized = self.api.authorizationManager.isAuthorized()

        logger.info(
            "Spotify.handleChangesToAuthorizationManager: isAuthorized: \(self.isAuthorized)"
        )

        self.retrieveCurrentUser()

        do {
            // Encode the authorization information to data.
            let authManagerData = try JSONEncoder().encode(
                self.api.authorizationManager
            )

            // Save the data to the keychain.
            RBSecrets.setSecret(s: .authorizationManager, v: authManagerData)
        } catch {
            logger.critical(
                "couldn't encode authorizationManager for storage " +
                    "in keychain:\n\(error)"
            )
        }
    }

    /**
     Removes `api.authorizationManager` from the keychain and sets
     `currentUser` to `nil`.

     This method is called everytime `api.authorizationManager.deauthorize` is
     called.
     */
    func authorizationManagerDidDeauthorize() {
//        withAnimation(LoginView.animation) {
//            self.isAuthorized = false
//        }

        self.currentUser = nil

        /*
         Remove the authorization information from the keychain.

         If you don't do this, then the authorization information
         that you just removed from memory by calling
         `SpotifyAPI.authorizationManager.deauthorize()` will be
         retrieved again from persistent storage after this app is
         quit and relaunched.
         */
        RBSecrets.deleteSecret(s: .authorizationManager)
        logger.info("did remove authorization manager from keychain")
    }

    /**
     Returns the current OAuth access token if available.
     This token can be used for librespot authentication.
     */
    func getAccessToken() -> String? {
        return api.authorizationManager.accessToken
    }

    /**
     Retrieve the current user.

     - Parameter onlyIfNil: Only retrieve the user if `self.currentUser`
     is `nil`.
     */
    func retrieveCurrentUser(onlyIfNil: Bool = true) {
        if onlyIfNil, self.currentUser != nil {
            return
        }

        guard self.isAuthorized else { return }

        self.api.currentUserProfile()
            .receive(on: RunLoop.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        logger.error("couldn't retrieve current user: \(error)")
                        self.api.authorizationManager.deauthorize()
                        self.authorize()
                    }
                },
                receiveValue: { user in
                    self.currentUser = user
                }
            )
            .store(in: &self.cancellables)
    }
}
