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
    }

    // let's use this to collect some secrets
    static func getSecret(s: Secret) -> String {
        let keychain = KeychainSwift()
        if let key = keychain.get(s.rawValue) {
            return key
        } else {
            fatalError(String.init(format: "Unable to load <%@> from login Keychain", s.rawValue))
        }
    }
}
