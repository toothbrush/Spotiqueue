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
    return [RBSongBridge get_current_song];
}

SCM pause_or_unpause(void) {
    return [RBSongBridge pause_or_unpause];
}

SCM next_song(void) {
    return scm_from_bool([RBSongBridge next_song]);
}
