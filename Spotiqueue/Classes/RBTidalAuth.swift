//
//  RBTidalAuth.swift
//  Spotiqueue
//
//  Created by Paul on 2/3/26.
//  Copyright © 2026 Rustling Broccoli. All rights reserved.
//

import Combine
import Foundation

struct TidalTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: UInt64
    let expiresAt: Date
}

final class RBTidalAuth: ObservableObject {
    // TODO: Replace with your Tidal application client ID
    static let clientId = "YOUR_TIDAL_CLIENT_ID"

    @Published var isAuthorized = false
    @Published var userCode: String?
    @Published var verificationURL: String?

    private var tokens: TidalTokens?
    private var pollingTimer: Timer?

    var accessToken: String? { tokens?.accessToken }
    var refreshToken: String? { tokens?.refreshToken }
    var userId: UInt64? { tokens?.userId }

    init() {
        loadTokens()
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
        self.userCode = nil
        self.verificationURL = nil
        self.pollingTimer?.invalidate()
        self.pollingTimer = nil
        RBSecrets.deleteSecret(s: .tidalAuth)
        logger.info("Tidal auth deauthorized and keychain cleared")
    }

    // MARK: - Device Code Flow

    func startDeviceCodeFlow() {
        let url = URL(string: "https://auth.tidal.com/v1/oauth2/device_authorization")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(Self.clientId)&scope=r_usr+w_usr"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                logger.error("Device auth request failed: \(error)")
                return
            }
            guard let data = data else {
                logger.error("Device auth returned no data")
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    logger.error("Device auth response is not a JSON object")
                    return
                }

                guard let deviceCode = json["deviceCode"] as? String,
                      let userCode = json["userCode"] as? String,
                      let verificationUri = json["verificationUri"] as? String,
                      let interval = json["interval"] as? Int
                else {
                    logger.error("Device auth response missing expected fields: \(json)")
                    return
                }

                logger.info("Tidal device code received. User code: \(userCode)")

                DispatchQueue.main.async {
                    self.userCode = userCode
                    self.verificationURL = verificationUri

                    // Open browser for the user
                    let fullURL = "\(verificationUri)/\(userCode)"
                    if let url = URL(string: fullURL) {
                        NSWorkspace.shared.open(url)
                    }

                    // Start polling for token
                    self.startPolling(deviceCode: deviceCode, interval: TimeInterval(interval))
                }
            } catch {
                logger.error("Failed to parse device auth response: \(error)")
            }
        }.resume()
    }

    private func startPolling(deviceCode: String, interval: TimeInterval) {
        self.pollingTimer?.invalidate()
        let pollInterval = max(interval, 5) // At least 5 seconds between polls
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(pollInterval), repeats: true) { [weak self] timer in
            self?.pollForToken(deviceCode: deviceCode, timer: timer)
        }
    }

    private func pollForToken(deviceCode: String, timer: Timer) {
        let url = URL(string: "https://auth.tidal.com/v1/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(Self.clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code&scope=r_usr+w_usr"
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                logger.error("Token poll request failed: \(error)")
                return
            }
            guard let data = data else { return }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 400 {
                // Expected: authorization_pending — keep polling
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let subStatus = json["sub_status"] as? Int, subStatus == 1002
                {
                    logger.debug("Tidal auth: authorization pending, continuing to poll...")
                    return
                }
                // Some other 400 error — log but keep polling
                logger.warning("Tidal token poll got 400: \(String(data: data, encoding: .utf8) ?? "?")")
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
                guard let user = json["user"] as? [String: Any],
                      let userId = user["userId"] as? UInt64
                else {
                    logger.error("Token response missing user.userId: \(json)")
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
                    timer.invalidate()
                    self.pollingTimer = nil
                    self.tokens = tokens
                    self.saveTokens(tokens)
                    self.userCode = nil
                    self.verificationURL = nil
                    self.isAuthorized = true
                }
            } catch {
                logger.error("Failed to parse token response: \(error)")
            }
        }.resume()
    }
}
