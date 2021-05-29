//
//  SpotifySong.swift
//  Spotiqueue
//
//  Created by Paul on 18/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa
import SpotifyWebAPI

final class RBSpotifySongTableRow: NSObject {

    @objc dynamic var title: String
    @objc dynamic var artist: String
    @objc dynamic var album: String!
    @objc dynamic var album_uri: String!
    @objc dynamic var track_number: Int
    @objc dynamic var disc_number: Int
    @objc dynamic var year: Int
    @objc dynamic var length: String {
        get {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.day, .hour, .minute, .second]
            formatter.unitsStyle = .positional
            formatter.maximumUnitCount = 0
            let seconds = Double(self.durationSeconds)
            return formatter.string(from: seconds)!
        }
    }

    var track_uri: String
    var durationSeconds: Int
    var album_image: SpotifyImage?

    convenience init(track: Track) {
        self.init(track: track, album: track.album!)
    }

    init(track: Track, album: Album) {
        self.title = track.name
        self.track_uri = track.uri!
        self.artist = track.consolidated_name()

        self.album = album.name
        self.album_uri = album.uri!
        self.album_image = album.images?.suffix(2).first

        if let releaseDate = album.releaseDate {
            self.year = Calendar.iso8601.component(.year, from: releaseDate)
        } else {
            self.year = 0
        }

        self.track_number = track.trackNumber!
        self.disc_number = track.discNumber!

        self.durationSeconds = track.durationMS! / 1000
        super.init()
    }

    static let trackSortDescriptors: [NSSortDescriptor] = [
            NSSortDescriptor(key: "year", ascending: true),
            NSSortDescriptor(key: "disc_number", ascending: true),
            NSSortDescriptor(key: "album_uri", ascending: true),
            NSSortDescriptor(key: "track_number", ascending: true),
        ]
}
