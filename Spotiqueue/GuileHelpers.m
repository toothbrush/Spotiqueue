//
//  NSObject+RBGuileHelpers.m
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

#import "GuileHelpers.h"
#import "Spotiqueue-Swift.h"

/// Meh, i can't directly use C-macros in Swift, and a lot of useful things are C macros.  Here i'll re-expose a few as Objective-C functions.

SCM _scm_empty_list(void) {
    return SCM_EOL;
}

bool _scm_is_true(SCM value) {
    return scm_is_true(value);
}

SCM _scm_false(void) {
    return SCM_BOOL_F;
}

SCM _scm_true(void) {
    return SCM_BOOL_T;
}

SCM get_homedir(void) {
    return scm_from_utf8_string(NSHomeDirectory().UTF8String);
}

SCM current_track(void) {
    return [RBGuileBridge get_current_track];
}

SCM _scm_list_of_strings(NSArray* strings) {
    SCM lst = scm_make_list(scm_from_uint64([strings count]), SCM_UNDEFINED);

    int32_t pos = 0;
    for (NSString* s in strings) {
        scm_list_set_x(lst, scm_from_int32(pos), scm_from_utf8_string([s UTF8String]));
        pos++;
    }

    return lst;
}

SCM pause_or_unpause(void) {
    return [RBGuileBridge pause_or_unpause];
}

SCM _scm_to_bool(bool x) {
    return scm_from_bool(x);
}

SCM next_track(void) {
    return [RBGuileBridge next_track];
}

SCM player_state(void) {
    return [RBGuileBridge get_player_state];
}

SCM focus_search_box(void) {
    return [RBGuileBridge focus_search_box];
}

SCM key_to_guile_struct(UInt16 keycode, bool ctrl, bool command, bool alt, bool shift) {
    SCM vtable = scm_c_public_ref("spotiqueue keybindings", "<kbd>");
    return scm_make_struct_no_tail(vtable,
                                   scm_list_5(scm_from_unsigned_integer(keycode),
                                              scm_from_bool(ctrl),
                                              scm_from_bool(command),
                                              scm_from_bool(alt),
                                              scm_from_bool(shift)
                                              )
                                   );
}

SCM queue_delete_selected(void) {
    return [RBGuileBridge queue_delete_selected_tracks];
}

SCM get_tracks_from(NSArray* realTracks) {
    // https://developer.apple.com/documentation/swift/int
    // On 32-bit platforms, Int is the same size as Int32, and on 64-bit platforms, Int is the same size as Int64.
    SCM tracks = scm_make_list(scm_from_int64([realTracks count]),
                               SCM_UNDEFINED);
    int32_t pos = 0;
    for (RBSpotifyItem* t in realTracks) {
        if ([t itemType] == ItemTypePlaylist) {
            scm_list_set_x(tracks, scm_from_int32(pos), playlist_to_scm_record(t));
        } else {
            scm_list_set_x(tracks, scm_from_int32(pos), track_to_scm_record(t));
        }
        pos++;
    }

    return tracks;
}

SCM queue_get_tracks(void) {
    return get_tracks_from([RBGuileBridge queue_get_tracks]);
}

SCM search_get_selection(void) {
    return get_tracks_from([RBGuileBridge search_get_selection]);
}

SCM alert_popup(SCM title, SCM message) {
    NSString* objc_title = [[NSString alloc] initWithUTF8String: scm_to_utf8_string(title)];
    NSString* objc_message = [[NSString alloc] initWithUTF8String: scm_to_utf8_string(message)];
    [RBGuileBridge alert_popupWithTitle:objc_title message:objc_message];
    return _scm_true();
}

void register_funcs_objc(void) {
    scm_c_define_gsubr("player:alert", 2, 0, 0, &alert_popup);
    scm_c_define_gsubr("player:auto-advance", 0, 0, 0, &auto_advance);
    scm_c_define_gsubr("player:current-track", 0, 0, 0, &current_track);
    scm_c_define_gsubr("player:homedir", 0, 0, 0, &get_homedir);
    scm_c_define_gsubr("player:next", 0, 0, 0, &next_track);
    scm_c_define_gsubr("player:set-auto-advance", 1, 0, 0, &set_auto_advance);
    scm_c_define_gsubr("player:state", 0, 0, 0, &player_state);
    scm_c_define_gsubr("player:toggle-pause", 0, 0, 0, &pause_or_unpause);
    scm_c_define_gsubr("queue:delete-selected-tracks", 0, 0, 0, &queue_delete_selected);
    scm_c_define_gsubr("queue:get-tracks", 0, 0, 0, &queue_get_tracks);
    scm_c_define_gsubr("queue:_set-tracks", 1, 0, 0, &queue_set_tracks);
    scm_c_define_gsubr("search:get-selection", 0, 0, 0, &search_get_selection);
    scm_c_define_gsubr("window:focus-search-box", 0, 0, 0, &focus_search_box);
    scm_c_export(
                 "player:alert",
                 "player:auto-advance",
                 "player:current-track",
                 "player:homedir",
                 "player:next",
                 "player:set-auto-advance",
                 "player:state",
                 "player:toggle-pause",
                 "queue:delete-selected-tracks",
                 "queue:get-tracks",
                 "queue:_set-tracks",
                 "search:get-selection",
                 "window:focus-search-box",
                 NULL);
    scm_simple_format(scm_current_output_port(), scm_from_utf8_string("guile ~a: Successfully booted.~%"), scm_list_1(scm_c_eval_string("(module-name (current-module))")));
}
