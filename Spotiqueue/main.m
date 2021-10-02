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
    @autoreleasepool {
        NSBundle* mainBundle;
        // Get the main bundle for the app.
        mainBundle = [NSBundle mainBundle];
        NSString* bundlePath = [mainBundle bundlePath];
        NSString* guileLibPath = [bundlePath stringByAppendingString:@"/Contents/Resources/guile-stdlib"];
        NSString* guileCcachePath = [bundlePath stringByAppendingString:@"/Contents/Resources/guile-ccache"];
        NSString* spotiqueueLibPath = [bundlePath stringByAppendingString:@"/Contents/Resources"];

        // I want my emojis to work! 😂
        // The million-dollar question is why the ; locale: .. hint at the top of the file is ignored.
        setenv("LANG", "en_US.UTF-8", 1);
        setenv("GUILE_LOAD_PATH", [guileLibPath UTF8String], 1);
        setenv("GUILE_LOAD_COMPILED_PATH", [guileCcachePath UTF8String], 1);

        scm_init_guile();
        // For this weird guy, see https://www.gnu.org/software/emacs/manual/html_mono/emacs.html#Recognize-Coding and https://www.gnu.org/software/guile/manual/html_node/Locales.html
        scm_setlocale(scm_from_int(LC_ALL), scm_from_utf8_string(""));
        scm_c_define_module("spotiqueue internal", &register_functions, NULL);

        /* This deserves some explanation.  We really don't want Spotiqueue to rely on users doing
         * `brew install guile` -- that would exclude half the world that doesn't like terminals.  So,
         * we vendor in the Guile stdlib.  However, that's not enough, because if my guile*.a file was
         * compiled in a different location than someone else's Guile installation path (e.g. the
         * Homebrew 3.0.7 vs 3.0.7_1 path issue) the built-in %load-path won't match up with theirs!
         * Subsequently (yes, there's more) if i don't also bundle in the ccache (*.go files) then at
         * startup Spotiqueue thinks its own stdlib is newer than the user's one and busily starts
         * compiling.  No bueno.  So we package up both the stdlib source & compiled files, and
         * manually tweak the search paths so that we're sure that only those files will be used.  Not
         * great, but it seems to work, and best of all, folks won't need to install Guile themselves
         * if they don't want to.
         */
        scm_c_eval_string([[NSString stringWithFormat:@"(set! %%load-path '(\"%@\" \"%@\"))", guileLibPath, spotiqueueLibPath] UTF8String]);
        scm_c_eval_string([[NSString stringWithFormat:@"(set! %%load-compiled-path '(\"%@\"))", guileCcachePath] UTF8String]);

        // Note that there are DRAGONS here.  We use a separate "Copy Files" Xcode build phase to put Scheme files into a "spotiqueue" subfolder inside the App bundle's Resources folder.  We do this so that the module names match up.  However, there doesn't seem to be an obvious way to get a direct pointer to the Resources folder, so we use this hack.
        scm_c_primitive_load_path("spotiqueue/init");
    }

    return NSApplicationMain(argc, argv);
}
