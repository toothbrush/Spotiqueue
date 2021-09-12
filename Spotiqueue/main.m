//
//  main.m
//  appkit-guile
//
//  Created by Paul on 6/9/21.
//

#import <Cocoa/Cocoa.h>
#import <libguile.h>
#import "GuileHelpers.h"

static void register_functions (void* data)
{
    register_funcs_objc();
}

int main(int argc, const char * argv[]) {
    scm_init_guile();
    scm_c_define_module("spotiqueue internal", &register_functions, NULL);

    @autoreleasepool {
        NSBundle* mainBundle;
        // Get the main bundle for the app.
        mainBundle = [NSBundle mainBundle];
        // TODO add a load path, just call init.scm, and be done with it.
        scm_c_primitive_load([[mainBundle pathForResource:@"records" ofType:@"scm"] UTF8String]);
        scm_c_primitive_load([[mainBundle pathForResource:@"key-constants" ofType:@"scm"] UTF8String]);
        scm_c_primitive_load([[mainBundle pathForResource:@"keybindings" ofType:@"scm"] UTF8String]);
        scm_c_primitive_load([[mainBundle pathForResource:@"init" ofType:@"scm"] UTF8String]);
    }

    return NSApplicationMain(argc, argv);
}
