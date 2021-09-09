//
//  RBSongBridge.swift
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

@objc class RBSongBridge: NSObject {
    var spotify_uri: String

    init(song: RBSpotifySong) {
        spotify_uri = song.spotify_uri
    }

    static func player_playing_hook(song_uri: String) {
        DispatchQueue.main.async {
            let hook = scm_variable_ref(scm_c_lookup("player-started-hook"))

            if scm_to_bool(scm_hook_p(hook)) == 1 {
                scm_run_hook(hook, scm_list_1(scm_from_utf8_string(song_uri)))
            } else {
                logger.error("Expected a hook, found instead: ")
                scm_display(hook, scm_current_output_port())
                scm_newline(scm_current_output_port())
            }
        }
    }
}
