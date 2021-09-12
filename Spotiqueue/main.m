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
        // Note that there are DRAGONS here.  We use a separate "Copy Files" Xcode build phase to put Scheme files into a "spotiqueue" subfolder inside the App bundle's Resources folder.  We do this so that the module names match up.  However, there doesn't seem to be an obvious way to get a direct pointer to the Resources folder, so we use this hack.
        // Subsequently we need to add a (add-to-load-path ..) in init.scm, but i'll continue the story there.
        scm_c_primitive_load([[mainBundle pathForResource:@"spotiqueue/init" ofType:@"scm"] UTF8String]);
    }

    return NSApplicationMain(argc, argv);
}
