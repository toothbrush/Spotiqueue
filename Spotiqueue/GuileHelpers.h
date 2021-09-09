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

SCM _scm_empty_list(void);
bool _scm_is_true(SCM value);
SCM get_homedir(void);

NS_ASSUME_NONNULL_END
