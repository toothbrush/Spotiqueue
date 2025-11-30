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
        case authorizationManager = "spotiqueue_authorization_manager_v3"
    }

    static let keychain = KeychainSwift()

    // let's use this to collect some secrets
    static func getSecret(s: Secret) -> String? {
#if DEBUG
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory,
                                                     in: .userDomainMask).first!
        let fileURL = appSupportDir.appendingPathComponent("\(s.rawValue).txt")
        logger.info("Read <\(s.rawValue)> from \(fileURL)")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let contentFromFile = try String(contentsOfFile: fileURL.path,
                                                 encoding: .utf8)
                return contentFromFile
            } catch {
                logger.error("Error reading file: \(error)")
            }
        }
#else
        if let key = keychain.get(s.rawValue) {
            return key
        }
#endif
        logger.critical("Failure to read <\(s.rawValue)> from Keychain!")
        logger.debug("Keychain.lastResultCode = \(self.keychain.lastResultCode)")
        return nil
    }

    static func setSecret(s: Secret, v: Data) {
#if DEBUG
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory,
                                                     in: .userDomainMask).first!
        let fileURL = appSupportDir.appendingPathComponent("\(s.rawValue).txt")
        logger.info("Writing key to \(fileURL)")
        do {
            try String(decoding: v, as: UTF8.self).write(toFile: fileURL.path,
                                                         atomically: true,
                                                         encoding: .utf8)
        } catch {
            logger.error("Error writing file: \(error)")
        }
#else
        // Fine, only touch the Keychain proper if we're in real-life mode.
        if !self.keychain.set(v, forKey: s.rawValue, withAccess: .accessibleAfterFirstUnlock) {
            logger.critical("Failure to save <\(s.rawValue)> to keychain")
            logger.debug("Keychain.lastResultCode = \(self.keychain.lastResultCode)")
        }
#endif
    }

    static func deleteSecret(s: Secret) {
        if !self.keychain.delete(s.rawValue) {
            logger.critical("Failure to remove <\(s.rawValue)> from keychain")
            logger.debug("Keychain.lastResultCode = \(self.keychain.lastResultCode)")
        }
    }
}
