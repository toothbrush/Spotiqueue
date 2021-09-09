//
//  main.m
//  appkit-guile
//
//  Created by Paul on 6/9/21.
//

#import <Cocoa/Cocoa.h>
#import <libguile.h>
#import "GuileHelpers.h"

static void* register_functions (void* data)
{
    scm_c_define_gsubr("spotiqueue:get-homedir", 0, 0, 0, &get_homedir);
    scm_c_define_gsubr("spotiqueue:current-song", 0, 0, 0, &current_song);
    scm_display(scm_from_utf8_string("guile: Successfully booted.\n"), scm_current_output_port());
    return NULL;
}

int main(int argc, const char * argv[]) {
    scm_init_guile();
    scm_with_guile(&register_functions, NULL);

    @autoreleasepool {
        NSBundle* mainBundle;
        // Get the main bundle for the app.
        mainBundle = [NSBundle mainBundle];
        NSString* init_scm = [mainBundle pathForResource:@"init" ofType:@"scm"];
        scm_c_primitive_load([init_scm UTF8String]);
    }

    return NSApplicationMain(argc, argv);
}
