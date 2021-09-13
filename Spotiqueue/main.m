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
    // I want my emojis to work! 😂
    // The million-dollar question is why the ; locale: .. hint at the top of the file is ignored.
    setenv("LANG", "en_US.UTF-8", 1);

    scm_init_guile();
    // For this weird guy, see https://www.gnu.org/software/emacs/manual/html_mono/emacs.html#Recognize-Coding and https://www.gnu.org/software/guile/manual/html_node/Locales.html
    scm_setlocale(scm_from_int(LC_ALL), scm_from_utf8_string(""));
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
