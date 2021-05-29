//
//  SpotifyAPIExtensions.swift
//  Spotiqueue
//
//  Created by Paul on 29/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import SpotifyWebAPI
import Combine

extension SpotifyAPI {

    /**
     Retrieves the *full* versions of all the albums of a given artist.

     - Parameters:
     - artist: The URI for an artist
     - market: *Optional*. An [ISO 3166-1 alpha-2 country code][2] or the
     string "from_token". Provide this parameter if you want to apply
     [Track Relinking][1].
     - Returns: A publisher that publishes an array of the full versions of
     album objects, **one page at a time**. Each page will contain up to
     50 albums.

     [3]: https://developer.spotify.com/documentation/general/guides/track-relinking-guide/
     */
    func artistFullAlbums(
        _ artist: SpotifyURIConvertible
    ) -> AnyPublisher<[Album], Error> {

        self.artistAlbums(
            artist,
            limit: 20)
            .extendPages(self)
            // extract the URIs of the albums from each page
            .map { albumsPage in
                albumsPage.items.compactMap(\.uri)
            }
            .flatMap { albumURIs -> AnyPublisher<[Album?], Error> in
                return self.albums(albumURIs)
            }
            // remove the `nil` items from the array of albums
            .map { $0.compactMap { $0 } }
            .eraseToAnyPublisher()
    }
}
