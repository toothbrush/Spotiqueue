//
//  RBGuileBridge.swift
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation
import AppKit

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
    // We choose not to do exception handling here because it involves only "our" code.
    scm_call_5(scm_c_public_ref("spotiqueue records", "make-track"),
               scm_from_utf8_string(track.spotify_uri), // uri
               scm_from_utf8_string(track.title), // title
               scm_from_utf8_string(track.artist), // artist
               scm_from_utf8_string(track.album), // album
               scm_from_int32(Int32(track.durationSeconds))) // duration in seconds
}

@_cdecl("playlist_to_scm_record")
public func playlist_to_scm_record(track: RBSpotifyItem) -> SCM {
    // Same caveats apply as with `track_to_scm_record`.
    scm_call_2(scm_c_public_ref("spotiqueue records", "make-playlist"),
               scm_from_utf8_string(track.spotify_uri), // uri
               scm_from_utf8_string(track.title)) // title
}

// Eh, okay, for convenience let's say we expect this to be a list of strings with Spotify IDs.
// Over in Guile land we have the wrapper `queue:set-tracks` which ensures we pass strings to `queue:_set-tracks`, this function here.
@_cdecl("queue_insert_tracks")
public func queue_insert_tracks(tracks: SCM, at: SCM) -> SCM {
    guard _scm_is_true(scm_list_p(tracks)) else {
        logger.error("`tracks` was not a list.")
        return _scm_false()
    }
    guard _scm_is_true(scm_integer_p(at)) else {
        logger.error("`at` was not an integer.")
        return _scm_false()
    }
    let at: Int = Int(scm_to_int64(at)).clamped(fromInclusive: 0,
                                                toInclusive: AppDelegate.appDelegate().queue.endIndex)

    let len: Int = Int(scm_to_int64(scm_length(tracks)))
    var i = 0
    var swift_tracks: [String] = []
    var tracks_rest: SCM = tracks

    while i < len && scm_is_pair(tracks_rest) != 0 {
        let elt: SCM = scm_car(tracks_rest)
        if _scm_is_true(scm_string_p(elt)) {
            if let str = String(utf8String: scm_to_utf8_string(elt)) {
                swift_tracks.append(str)
            }
        }
        tracks_rest = scm_cdr(tracks_rest)
        i += 1
    }

    block_on_main {
        AppDelegate.appDelegate().queueTableView.insertURIsInQueue(swift_tracks.joined(separator: "\n"), at: at)
    }
    return _scm_true()
}

@_cdecl("queue_set_tracks")
public func queue_set_tracks(tracks: SCM) -> SCM {
    guard _scm_is_true(scm_list_p(tracks)) else {
        logger.error("`tracks` was not a list.")
        return _scm_false()
    }
    return block_on_main {
        AppDelegate.appDelegate().queue = []
        return queue_insert_tracks(tracks: tracks, at: scm_from_int64(0))
    }
}

@objc class RBGuileBridge: NSObject {
    private static func call_hook(hook_name: String, args_list: SCM) {
        assert(Thread.isMainThread)

        // HMMM big TODO here.  We actually shouldn't run user hooks on the Main thread, because the user may sleep(4), but we can't simply use DispatchQueue.global(qos: .userInitiated).async {}, either, since even after scm_init_guile() we aren't able to do the scm_c_lookup.  Unsure how to share state!

        let hook = scm_c_public_ref("spotiqueue base", hook_name)

        if _scm_is_true(scm_hook_p(hook)) {
            scm_call_2(scm_c_public_ref("spotiqueue exceptions", "spot:safe-run-hook"),
                       hook,
                       args_list)
        } else {
            logger.error("Expected a hook, found instead: ")
            scm_display(hook, scm_current_output_port())
            scm_newline(scm_current_output_port())
        }
    }

    static func selection_copied_hook(copied: [String]) {
        let args: SCM = _scm_list_of_strings(copied)
        self.call_hook(hook_name: "selection-copied-hook", args_list: scm_list_1(args))
    }

    static func player_playing_hook(track: RBSpotifyItem) {
        self.call_hook(hook_name: "player-started-hook",
                       args_list: scm_list_1(track_to_scm_record(track: track)))
    }

    static func player_endoftrack_hook(track: RBSpotifyItem) {
        self.call_hook(hook_name: "player-endoftrack-hook",
                       args_list: scm_list_1(track_to_scm_record(track: track)))
    }

    static func player_paused_hook() {
        self.call_hook(hook_name: "player-paused-hook", args_list: _scm_empty_list())
    }

    static func player_unpaused_hook() {
        self.call_hook(hook_name: "player-unpaused-hook", args_list: _scm_empty_list())
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

    @objc static func search_get_selection() -> [RBSpotifyItem] {
        block_on_main {
            AppDelegate.appDelegate().searchTableView.selectedSearchTracks()
        }
    }

    @objc static func alert_popup(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    enum KeyMap: String {
        case queue = "queue-panel-map"
        case search = "search-panel-map"
        case global = "global-map"
    }

    static func guile_handle_key(map: KeyMap, keycode: UInt16, control: Bool, command: Bool, alt: Bool, shift: Bool) -> Bool {
        let guile_key = key_to_guile_struct(keycode, control, command, alt, shift)
        let action: SCM = scm_hash_ref(scm_c_public_ref("spotiqueue base", map.rawValue),
                                       guile_key,
                                       _scm_false())

        if !_scm_is_true(action) {
#if DEBUG
            scm_simple_format(_scm_true(),
                              scm_from_utf8_string("[keymap=~a] ~a not bound by user.~%"),
                              scm_list_2(
                                scm_from_utf8_string(map.rawValue.cString(using: .utf8)),
                                guile_key))
#endif
            return false
        }

        // We are handling exceptions in user-bound keys.
        scm_call_1(scm_c_public_ref("spotiqueue exceptions", "spot:with-exn-handler"),
                   action)
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
                scm_call_1(scm_c_public_ref("spotiqueue exceptions", "spot:safe-primitive-load"),
                           scm_from_utf8_string(filePath.cString(using: .utf8)!))
            } else {
                logger.warning("User-config file doesn't exist, skipping.")
            }
        }
    }
}
