//
//  TrackExtensions.swift
//  Spotiqueue
//
//  Created by Paul on 20/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation
import SpotifyWebAPI

extension Track {
    func consolidated_name() -> String {
        guard self.artists != nil else {
            return "<no artist>"
        }

        let names = self.artists!.map { artist -> String in
            artist.name
        }

        let proposedName = names.prefix(3).joined(separator: ", ")

        if artists!.count > 3 {
            return proposedName + ", …"
        } else {
            return proposedName
        }
    }
}
