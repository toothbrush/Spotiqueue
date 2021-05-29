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

            // always show at least minutes and seconds.
            if self.durationSeconds >= 3600 {
                formatter.allowedUnits = [.hour, .minute, .second]
            } else {
                formatter.allowedUnits = [.minute, .second]
            }
            formatter.unitsStyle = .positional
            formatter.maximumUnitCount = 0
            formatter.zeroFormattingBehavior = .pad
            let seconds = Double(self.durationSeconds)
            let string = formatter.string(from: seconds)!
            return string.hasPrefix("0") ?
                .init(string.dropFirst()) :
                string
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
