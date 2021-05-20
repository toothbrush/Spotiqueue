//
//  SpotifySong.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import SpotifyWebAPI

class RBSpotifySongTableRow: NSObject {

    @objc dynamic var title: String
    @objc dynamic var artist: String
    @objc dynamic var album: String
    @objc dynamic var track_number: Int

    var track: Track

    init(t: Track) {
        track = t
        title = t.name
        artist = t.consolidated_name()
        album = t.album?.name ?? "<no album>"
        track_number = t.trackNumber ?? 0
    }
}
