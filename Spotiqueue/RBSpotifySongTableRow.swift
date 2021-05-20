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

    // TODO make this a getter.
    @objc dynamic var title: String

    var track: Track

    init(t: Track) {
        track = t
        title = t.name

        // maybe go off and fetch song metadata in another thread.
    }
}
