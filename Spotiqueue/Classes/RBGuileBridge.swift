//
//  RBGuileBridge.swift
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

func block_on_main<A>(closure: () -> A) -> A {
    if Thread.isMainThread {
        return closure()
    } else {
        return DispatchQueue.main.sync {
            closure()
        }
    }
}

@_cdecl("auto_advance")
public func auto_advance() -> SCM {
    block_on_main {
        _scm_to_bool(AppDelegate.appDelegate().shouldAutoAdvance())
    }
}

@_cdecl("set_auto_advance")
public func set_auto_advance(data: SCM) -> SCM {
    block_on_main {
        AppDelegate.appDelegate().setAutoAdvance(newValue: scm_to_bool(data) == 1)
        return _scm_true()
    }
}

@_cdecl("track_to_scm_record")
public func track_to_scm_record(track: RBSpotifyItem) -> SCM {
    // Beware, _make-track is the generated record creator thing, but it's a syntax transformer which can't be called directly, so we have a wrapper function called make-track.
    scm_call_5(scm_variable_ref(scm_c_lookup("make-track")),
               scm_from_utf8_string(track.spotify_uri), // uri
               scm_from_utf8_string(track.title), // title
               scm_from_utf8_string(track.artist), // artist
               scm_from_utf8_string(track.album), // album
               scm_from_int32(Int32(track.durationSeconds))) // duration in seconds
}

@objc class RBGuileBridge: NSObject {
    private static func hook_with_track(hook_name: String, track: RBSpotifyItem) {
        let track_record = track_to_scm_record(track: track)
        self.hook_1(hook_name: hook_name, arg1: track_record)
    }

    private static func hook_1(hook_name: String, arg1: SCM) {
        assert(Thread.isMainThread)

        let hook = scm_variable_ref(scm_c_lookup(hook_name))

        if _scm_is_true(scm_hook_p(hook)) {
            scm_run_hook(hook, scm_list_1(arg1))
        } else {
            logger.error("Expected a hook, found instead: ")
            scm_display(hook, scm_current_output_port())
            scm_newline(scm_current_output_port())
        }
    }

    private static func hook_0(hook_name: String) {
        assert(Thread.isMainThread)

        // HMMM big TODO here.  We actually shouldn't run user hooks on the Main thread, because the user may sleep(4), but we can't simply use DispatchQueue.global(qos: .userInitiated).async {}, either, since even after scm_init_guile() we aren't able to do the scm_c_lookup.  Unsure how to share state!

        let hook = scm_variable_ref(scm_c_lookup(hook_name))

        if _scm_is_true(scm_hook_p(hook)) {
            scm_run_hook(hook, _scm_empty_list())
        } else {
            logger.error("Expected a hook, found instead: ")
            scm_display(hook, scm_current_output_port())
            scm_newline(scm_current_output_port())
        }
    }

    static func selection_copied_hook(copied: [String]) {
        let args: SCM = _scm_list_of_strings(copied)
        hook_1(hook_name: "selection-copied-hook", arg1: args)
    }

    static func player_playing_hook(track: RBSpotifyItem) {
        self.hook_with_track(hook_name: "player-started-hook", track: track)
    }

    static func player_endoftrack_hook(track: RBSpotifyItem) {
        self.hook_with_track(hook_name: "player-endoftrack-hook", track: track)
    }

    static func player_paused_hook() {
        self.hook_0(hook_name: "player-paused-hook")
    }

    static func player_unpaused_hook() {
        self.hook_0(hook_name: "player-unpaused-hook")
    }

    @objc static func pause_or_unpause() -> SCM {
        block_on_main {
            AppDelegate.appDelegate().playOrPause(Self.className())
            return _scm_true()
        }
    }

    @objc static func next_track() -> SCM {
        block_on_main {
            let success = AppDelegate.appDelegate().playNextQueuedTrack()
            return _scm_to_bool(success)
        }
    }

    @objc static func focus_search_box() -> SCM {
        block_on_main {
            AppDelegate.appDelegate().focusSearchBox()
            return _scm_true()
        }
    }

    @objc static func get_current_track() -> SCM {
        // We're liable to be calling this from a background thread.
        block_on_main {
            let track: RBSpotifyItem? = AppDelegate.appDelegate().currentTrack

            if let track = track {
                return track_to_scm_record(track: track)
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

    @objc static func queue_delete_selected_tracks() -> SCM {
        // I go through this song-and-dance because i expect actions from Scheme world to mostly be triggered by keypresses which originate on the Main thread.  So, we can't be saying dispatch-on-main-sync, because that causes a deadlock.  However, if we've connected to Scheme from, say, Emacs, we'll be on a background thread, and in that case we probably want the actions to be blocking so that our user knows when the action has completed (for example, they might be waiting for the queue to be successfully be cleared before enqueueing something new.
        block_on_main {
            AppDelegate.appDelegate().queueTableView.delete_selected_tracks()
            return _scm_true()
        }
    }

    @objc static func queue_get_tracks() -> [RBSpotifyItem] {
        block_on_main {
            AppDelegate.appDelegate().queue
        }
    }

    enum KeyMap: String {
        case queue = "queue-panel-map"
        case search = "search-panel-map"
        case global = "global-map"
    }

    static func guile_handle_key(map: KeyMap, keycode: UInt16, control: Bool, command: Bool, alt: Bool, shift: Bool) -> Bool {
        let guile_key = key_to_guile_struct(keycode, control, command, alt, shift)
        let action: SCM = scm_hash_ref(scm_variable_ref(scm_c_lookup(map.rawValue)),
                                       guile_key,
                                       _scm_false())

        if !_scm_is_true(action) {
            scm_simple_format(_scm_true(),
                              scm_from_utf8_string("[keymap=~a] ~a not bound by user.~%"),
                              scm_list_2(
                                scm_from_utf8_string(map.rawValue.cString(using: .utf8)),
                                guile_key))
            return false
        }

        scm_call_0(scm_eval(action, scm_current_module()))
        return true
    }

    public static func load_user_initscm_if_present() {
        // Now that the UI is ready, find and load a user's config in ~/.config/spotiqueue/init.scm, if it exists.
        let home = NSHomeDirectory()
        let url = NSURL(fileURLWithPath: home)
        if let pathComponent = url.appendingPathComponent(".config/spotiqueue/init.scm") {
            let filePath = pathComponent.path
            logger.info("Looking for user config in: \(filePath)...")
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                logger.info("User-config init.scm found.")
                scm_c_primitive_load(filePath.cString(using: .utf8)!)
            } else {
                logger.warning("User-config file doesn't exist, skipping.")
            }
        }
    }
}
