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
    @objc dynamic var album_uri: String
    @objc dynamic var track_number: Int
    @objc dynamic var disc_number: Int
    @objc dynamic var year: Int
    @objc dynamic var length: String {
        get {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour, .minute, .second]
            formatter.unitsStyle = .positional
            formatter.maximumUnitCount = 0
            let seconds = Double(self.track.durationMS ?? 0) / 1000
            return formatter.string(from: seconds)!
        }
    }

    var track: Track

    init(track: Track) {
        self.track = track
        self.title = track.name
        self.artist = track.consolidated_name()
        self.album = track.album?.name ?? "<no album>"
        self.album_uri = track.album?.uri ?? "<no album_uri>"
        self.track_number = track.trackNumber ?? 0
        self.disc_number = track.discNumber ?? 0
        self.year = -1
        if let release = track.album?.releaseDate {
            self.year = Calendar.iso8601.component(.year, from: release)
        }
        super.init()
    }

    static func trackSortDescriptors() -> [NSSortDescriptor] {
        return [
            NSSortDescriptor(key: "year", ascending: true),
            NSSortDescriptor(key: "disc_number", ascending: true),
            NSSortDescriptor(key: "album_uri", ascending: true),
            NSSortDescriptor(key: "track_number", ascending: true),
        ]
    }
}
