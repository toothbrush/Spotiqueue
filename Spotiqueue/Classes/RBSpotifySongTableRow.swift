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
            self.durationSeconds.positionalTime
        }
    }

    var track_uri: String
    var spotify_album: Album
    var spotify_artist: Artist
    var durationSeconds: TimeInterval
    var album_image: SpotifyImage?

    convenience init(track: Track) {
        guard let album = track.album else {
            fatalError("Trying to construct RBSpotifySongTableRow with simplified Track.")
        }
        guard let artist = track.artists?.first else {
            fatalError("Trying to construct RBSpotifySongTableRow with simplified Track.")
        }
        self.init(track: track, album: album, artist: artist)
    }

    init(track: Track, album: Album, artist: Artist) {
        self.spotify_album = album
        self.spotify_artist = artist

        self.title = track.name
        self.track_uri = track.uri!
        self.artist = track.consolidated_name()

        self.album = self.spotify_album.name
        self.album_uri = self.spotify_album.uri!
        self.album_image = self.spotify_album.images?.suffix(2).first

        if let releaseDate = self.spotify_album.releaseDate {
            self.year = Calendar.iso8601.component(.year, from: releaseDate)
        } else {
            self.year = 0
        }

        self.track_number = track.trackNumber!
        self.disc_number = track.discNumber!

        self.durationSeconds = Double(track.durationMS! / 1000)
        super.init()
    }

    static let trackSortDescriptors: [NSSortDescriptor] = [
            NSSortDescriptor(key: "year", ascending: true),
            NSSortDescriptor(key: "disc_number", ascending: true),
            NSSortDescriptor(key: "album_uri", ascending: true),
            NSSortDescriptor(key: "track_number", ascending: true),
        ]
}
