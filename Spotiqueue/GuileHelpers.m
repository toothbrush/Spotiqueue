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

SCM pause_or_unpause(void) {
    return [RBGuileBridge pause_or_unpause];
}

SCM next_song(void) {
    return scm_from_bool([RBGuileBridge next_song]);
}

SCM player_state(void) {
    return [RBGuileBridge get_player_state];
}

SCM key_to_guile_struct(UInt16 keycode) {
    SCM vtable = scm_variable_ref(scm_c_lookup("<kbd>"));
    return scm_make_struct_no_tail(vtable,
                                   scm_list_5(_scm_false(), // ctrl
                                              _scm_false(), // command
                                              _scm_false(), // alt
                                              _scm_false(), // shift
                                              scm_from_unsigned_integer(keycode))
                                   );
}
