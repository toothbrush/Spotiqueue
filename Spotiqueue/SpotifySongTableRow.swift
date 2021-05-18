//
//  SpotifySong.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class SpotifySongTableRow: NSObject {
    @objc dynamic var spotifyId: String

    init(songId: String) {
        spotifyId = songId

        // maybe go off and fetch song metadata in another thread.
    }
}
