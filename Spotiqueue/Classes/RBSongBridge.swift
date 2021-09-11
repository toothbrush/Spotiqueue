//
//  RBSongBridge.swift
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

@objc class RBSongBridge: NSObject {
    private static func song_to_scm_record(song: RBSpotifySong) -> SCM {
        return scm_call_5(scm_variable_ref(scm_c_lookup("make-song")),
                          scm_from_utf8_string(song.spotify_uri), // uri
                          scm_from_utf8_string(song.title), // title
                          scm_from_utf8_string(song.artist), // artist
                          scm_from_utf8_string(song.album), // album
                          scm_from_int32(Int32(song.durationSeconds))) // duration in seconds
    }

    private static func hook_with_song(hook_name: String, song: RBSpotifySong) {
        assert(Thread.isMainThread)

        let hook = scm_variable_ref(scm_c_lookup(hook_name))

        if _scm_is_true(scm_hook_p(hook)) {
            // Beware, make-song is the generated record creator thing, but it's a syntax transformer which can't be called directly, so we have a wrapper function called _make-song.
            let song_record = song_to_scm_record(song: song)
            scm_run_hook(hook, scm_list_1(song_record))
        } else {
            logger.error("Expected a hook, found instead: ")
            scm_display(hook, scm_current_output_port())
            scm_newline(scm_current_output_port())
        }
    }

    private static func hook_0(hook_name: String) {
        assert(Thread.isMainThread)

        let hook = scm_variable_ref(scm_c_lookup(hook_name))

        if _scm_is_true(scm_hook_p(hook)) {
            scm_run_hook(hook, _scm_empty_list())
        } else {
            logger.error("Expected a hook, found instead: ")
            scm_display(hook, scm_current_output_port())
            scm_newline(scm_current_output_port())
        }
    }

    static func player_playing_hook(song: RBSpotifySong) {
        hook_with_song(hook_name: "player-started-hook", song: song)
    }

    static func player_endoftrack_hook(song: RBSpotifySong) {
        hook_with_song(hook_name: "player-endoftrack-hook", song: song)
    }

    static func player_paused_hook() {
        hook_0(hook_name: "player-paused-hook")
    }

    static func player_unpaused_hook() {
        hook_0(hook_name: "player-unpaused-hook")
    }

    @objc static func get_current_song() -> SCM {
        // We're liable to be calling this from a background thread.
        let song: RBSpotifySong? = DispatchQueue.main.sync {
            AppDelegate.appDelegate().currentSong
        }

        if let song = song {
            return song_to_scm_record(song: song)
        } else {
            return _scm_false()
        }
    }
}
