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

@objc class RBGuileBridge: NSObject {
    private static func call_hook(hook_name: String, args_list: SCM) {
        assert(Thread.isMainThread)

        // HMMM big TODO here.  We actually shouldn't run user hooks on the Main thread, because the user may sleep(4), but we can't simply use DispatchQueue.global(qos: .userInitiated).async {}, either, since even after scm_init_guile() we aren't able to do the scm_c_lookup.  Unsure how to share state!

        let hook = scm_c_public_ref("spotiqueue init", hook_name)

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

    @objc static func queue_set_tracks(tracks: [String]) {
        block_on_main {
            AppDelegate.appDelegate().queue = []
            AppDelegate.appDelegate().queueTableView.addTracksToQueue(from: tracks)
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
        let action: SCM = scm_hash_ref(scm_c_public_ref("spotiqueue init", map.rawValue),
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
