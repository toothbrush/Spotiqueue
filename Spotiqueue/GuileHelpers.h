//
//  NSObject+RBGuileHelpers.h
//  Spotiqueue
//
//  Created by Paul on 9/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libguile.h>

NS_ASSUME_NONNULL_BEGIN

// We only need to expose things we'll actually be calling from outside of GuileHelpers.
SCM _scm_empty_list(void);
bool _scm_is_true(SCM value);
SCM _scm_false(void);
SCM _scm_true(void);
SCM _scm_to_bool(bool x);
SCM key_to_guile_struct(UInt16 keycode, bool ctrl, bool command, bool alt, bool shift);

void register_funcs_objc(void);

NS_ASSUME_NONNULL_END
