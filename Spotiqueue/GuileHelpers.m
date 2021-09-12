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

SCM current_song(void) {
    return [RBGuileBridge get_current_song];
}

SCM _scm_list_of_strings(NSArray* strings) {
    SCM lst = scm_make_list(scm_from_uint64([strings count]),
                            SCM_UNDEFINED);

    int32_t pos = 0;
    for (NSString* s in strings) {
        NSLog(@"string -> %@", s);
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

SCM next_song(void) {
    return [RBGuileBridge next_song];
}

SCM player_state(void) {
    return [RBGuileBridge get_player_state];
}

SCM key_to_guile_struct(UInt16 keycode, bool ctrl, bool command, bool alt, bool shift) {
    SCM vtable = scm_variable_ref(scm_c_lookup("<kbd>"));
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

void register_funcs_objc(void) {
    scm_c_define_gsubr("player:homedir", 0, 0, 0, &get_homedir);
    scm_c_define_gsubr("player:current-song", 0, 0, 0, &current_song);
    scm_c_define_gsubr("player:toggle-pause", 0, 0, 0, &pause_or_unpause);
    scm_c_define_gsubr("player:next", 0, 0, 0, &next_song);
    scm_c_define_gsubr("player:state", 0, 0, 0, &player_state);
    scm_c_define_gsubr("queue:delete-selected-tracks", 0, 0, 0, &queue_delete_selected);
    scm_c_export("player:homedir",
                 "player:current-song",
                 "player:toggle-pause",
                 "player:next",
                 "player:state",
                 "queue:delete-selected-tracks",
                 NULL);
    scm_simple_format(scm_current_output_port(), scm_from_utf8_string("guile ~a: Successfully booted.~%"), scm_list_1(scm_c_eval_string("(module-name (current-module))")));
}
