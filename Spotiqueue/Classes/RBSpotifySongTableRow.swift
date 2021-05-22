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

    init(track: Track) {
        self.track = track
        self.title = track.name
        self.artist = track.consolidated_name()
        self.album = track.album?.name ?? "<no album>"
        self.track_number = track.trackNumber ?? 0
        super.init()
    }
}
