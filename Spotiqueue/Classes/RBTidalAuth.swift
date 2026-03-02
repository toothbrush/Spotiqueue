//
//  RBTidalAuth.swift
//  Spotiqueue
//
//  Created by Paul on 2/3/26.
//  Copyright © 2026 Rustling Broccoli. All rights reserved.
//

import Cocoa
import Combine
import CommonCrypto

struct TidalTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: UInt64
    let expiresAt: Date
}

final class RBTidalAuth: ObservableObject {
    static let clientId = "e4eyNkuykj92jZlc"
    static let redirectURI = "spotiqueue://callback/tidal"

    @Published var isAuthorized = false

    private var tokens: TidalTokens?
    private var codeVerifier: String?
    private var state: String?

    var accessToken: String? { tokens?.accessToken }
    var refreshToken: String? { tokens?.refreshToken }
    var userId: UInt64? { tokens?.userId }

    init() {
        loadTokens()
    }

    // MARK: - PKCE Helpers

    private static func generateRandomString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        var result = ""
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        for byte in bytes {
            result.append(chars[chars.index(chars.startIndex, offsetBy: Int(byte) % chars.count)])
        }
        return result
    }

    private static func sha256Base64URL(_ input: String) -> String {
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Token Persistence

    private func loadTokens() {
        guard let json = RBSecrets.getSecret(s: .tidalAuth) else {
            logger.info("No saved Tidal tokens found")
            return
        }
        guard let data = json.data(using: .utf8) else { return }
        do {
            let saved = try JSONDecoder().decode(TidalTokens.self, from: data)
            self.tokens = saved
            self.isAuthorized = true
            logger.info("Loaded Tidal tokens from keychain (userId: \(saved.userId))")
        } catch {
            logger.error("Failed to decode saved Tidal tokens: \(error)")
        }
    }

    private func saveTokens(_ tokens: TidalTokens) {
        do {
            let data = try JSONEncoder().encode(tokens)
            RBSecrets.setSecret(s: .tidalAuth, v: data)
            logger.info("Saved Tidal tokens to keychain")
        } catch {
            logger.error("Failed to encode Tidal tokens: \(error)")
        }
    }

    func deauthorize() {
        self.tokens = nil
        self.isAuthorized = false
        self.codeVerifier = nil
        self.state = nil
        RBSecrets.deleteSecret(s: .tidalAuth)
        logger.info("Tidal auth deauthorized and keychain cleared")
    }

    // MARK: - PKCE Authorization Code Flow

    func startLogin() {
        let verifier = Self.generateRandomString(length: 128)
        let challenge = Self.sha256Base64URL(verifier)
        let stateValue = Self.generateRandomString(length: 32)

        self.codeVerifier = verifier
        self.state = stateValue

        var components = URLComponents(string: "https://login.tidal.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: "user.read playback collection.read collection.write playlists.read playlists.write search.read"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: stateValue),
        ]

        guard let url = components.url else {
            logger.error("Failed to build Tidal authorize URL")
            return
        }

        logger.info("Opening Tidal authorization URL in browser")
        NSWorkspace.shared.open(url)
    }

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.error("Failed to parse callback URL: \(url)")
            return
        }

        let params = Dictionary(uniqueKeysWithValues:
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        // Validate state
        guard let returnedState = params["state"], returnedState == self.state else {
            logger.error("Tidal callback state mismatch (CSRF protection)")
            return
        }

        guard let code = params["code"] else {
            let error = params["error"] ?? "unknown"
            logger.error("Tidal callback missing authorization code. Error: \(error)")
            return
        }

        guard let verifier = self.codeVerifier else {
            logger.error("No code verifier available — was startLogin() called?")
            return
        }

        // Exchange authorization code for tokens
        exchangeCodeForTokens(code: code, codeVerifier: verifier)
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) {
        let url = URL(string: "https://auth.tidal.com/v1/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParts = [
            "client_id=\(Self.clientId)",
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(Self.redirectURI)",
            "code_verifier=\(codeVerifier)",
        ]
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                logger.error("Token exchange request failed: \(error)")
                return
            }
            guard let data = data else {
                logger.error("Token exchange returned no data")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "?"
                logger.error("Token exchange failed (HTTP \(httpResponse.statusCode)): \(body)")
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    logger.error("Token response is not a JSON object")
                    return
                }

                guard let accessToken = json["access_token"] as? String,
                      let refreshToken = json["refresh_token"] as? String,
                      let expiresIn = json["expires_in"] as? Int
                else {
                    logger.error("Token response missing fields: \(json)")
                    return
                }

                // Extract user ID from the nested user object
                guard let userId = json["user_id"] as? UInt64
                else {
                    logger.error("Token response missing user_id: \(json)")
                    return
                }

                let tokens = TidalTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    userId: userId,
                    expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn))
                )

                logger.info("Tidal auth successful! userId: \(userId)")

                DispatchQueue.main.async {
                    self.codeVerifier = nil
                    self.state = nil
                    self.tokens = tokens
                    self.saveTokens(tokens)
                    self.isAuthorized = true
                }
            } catch {
                logger.error("Failed to parse token response: \(error)")
            }
        }.resume()
    }
}
