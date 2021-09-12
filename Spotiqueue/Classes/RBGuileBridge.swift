//
//  RBGuileBridge.swift
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

@objc class RBGuileBridge: NSObject {
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

    @objc static func pause_or_unpause() -> SCM {
        block_on_main {
            AppDelegate.appDelegate().playOrPause(Self.className())
            return _scm_true()
        }
    }

    @objc static func next_song() -> SCM {
        block_on_main {
            let success = AppDelegate.appDelegate().playNextQueuedTrack()
            return _scm_to_bool(success)
        }
    }

    @objc static func get_current_song() -> SCM {
        // We're liable to be calling this from a background thread.
        block_on_main {
            let song: RBSpotifySong? = AppDelegate.appDelegate().currentSong

            if let song = song {
                return song_to_scm_record(song: song)
            } else {
                return _scm_false()
            }
        }
    }

    @objc static func get_player_state() -> SCM {
        block_on_main {
            switch AppDelegate.appDelegate().playerState {
                case .Paused:
                    return scm_from_utf8_symbol("paused")
                case .Playing:
                    return scm_from_utf8_symbol("playing")
                case .Stopped:
                    return scm_from_utf8_symbol("stopped")
            }
        }
    }

    static func block_on_main(closure: () -> SCM) -> SCM {
        if Thread.isMainThread {
            return closure()
        } else {
            return DispatchQueue.main.sync {
                closure()
            }
        }
    }
    
    static func guile_handle_key(keycode: UInt16) -> Bool {
        // TODO handle all the modifiers, and allow different keymaps.
        let guile_key = key_to_guile_struct(keycode, false, false, false, false)
        let action: SCM = scm_hash_ref(scm_variable_ref(scm_c_lookup("queue-panel-map")),
                                       guile_key,
                                       _scm_false())
        
        if(!_scm_is_true(action)) {
            scm_simple_format(_scm_true(),
                              scm_from_utf8_string("~a not bound by user.~%"),
                              scm_list_1(guile_key))
            return false
        }

        scm_call_0(scm_eval(action, scm_current_module()))
        return true
    }
}
