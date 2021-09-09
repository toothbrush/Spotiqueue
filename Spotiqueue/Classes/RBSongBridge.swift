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

    static func player_playing_hook(song: RBSpotifySong) {
        DispatchQueue.main.async {
            let hook = scm_variable_ref(scm_c_lookup("player-started-hook"))

            if scm_to_bool(scm_hook_p(hook)) == 1 {
                // Beware, make-song is the generated record creator thing, but it's a syntax transformer which can't be called directly, so we have a wrapper function called _make-song.
                let song_record = scm_call_5(scm_variable_ref(scm_c_lookup("_make-song")),
                                             scm_from_utf8_string(song.spotify_uri), // uri
                                             scm_from_utf8_string(song.title), // title
                                             scm_from_utf8_string(song.artist), // artist
                                             scm_from_utf8_string(song.album), // album
                                             scm_from_int32(Int32(song.durationSeconds))) // duration in seconds
                scm_run_hook(hook, scm_list_1(song_record))
            } else {
                logger.error("Expected a hook, found instead: ")
                scm_display(hook, scm_current_output_port())
                scm_newline(scm_current_output_port())
            }
        }
    }
}
