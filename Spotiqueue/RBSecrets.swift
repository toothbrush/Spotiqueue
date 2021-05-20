//
//  Secrets.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import KeychainSwift

class RBSecrets: NSObject {
    enum Secret: String {
        case clientId = "spotiqueue_client_id"
        case clientSecret = "spotiqueue_client_secret"
        case authorizationManager = "spotiqueue_authorization_manager"
    }
    static let keychain = KeychainSwift()

    // let's use this to collect some secrets
    static func getSecret(s: Secret) -> String? {
        logger.info("Retrieving <\(s.rawValue)> from keychain.")
        if let key = keychain.get(s.rawValue) {
            return key
        }
        logger.critical("Failure to read <\(s.rawValue)> from keychain")
        return nil
    }

    static func setSecret(s: Secret, v: Data) {
        if !keychain.set(v, forKey: s.rawValue) {
            logger.critical("Failure to save <\(s.rawValue)> to keychain")
        }
    }

    static func deleteSecret(s: Secret) {
        if !keychain.delete(s.rawValue) {
            logger.critical("Failure to remove <\(s.rawValue)> from keychain")
        }
    }
}
