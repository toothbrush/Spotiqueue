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
    scm_c_define_gsubr("spotiqueue:get-homedir", 0, 0, 0, &get_homedir);
    scm_c_define_gsubr("spotiqueue:current-song", 0, 0, 0, &current_song);
    scm_c_define_gsubr("spotiqueue:toggle-pause", 0, 0, 0, &pause_or_unpause);
    scm_c_define_gsubr("spotiqueue:next", 0, 0, 0, &next_song);
    scm_c_export("spotiqueue:get-homedir",
                 "spotiqueue:current-song",
                 "spotiqueue:toggle-pause",
                 NULL);
    scm_simple_format(scm_current_output_port(), scm_from_utf8_string("guile ~a: Successfully booted.~%"), scm_list_1(scm_c_eval_string("(module-name (current-module))")));
}

int main(int argc, const char * argv[]) {
    scm_init_guile();
    scm_c_define_module("spotiqueue internal", &register_functions, NULL);

    @autoreleasepool {
        NSBundle* mainBundle;
        // Get the main bundle for the app.
        mainBundle = [NSBundle mainBundle];
        NSString* records_scm = [mainBundle pathForResource:@"records" ofType:@"scm"];
        scm_c_primitive_load([records_scm UTF8String]);
        NSString* init_scm = [mainBundle pathForResource:@"init" ofType:@"scm"];
        scm_c_primitive_load([init_scm UTF8String]);
    }

    return NSApplicationMain(argc, argv);
}
