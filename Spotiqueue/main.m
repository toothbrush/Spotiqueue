//
//  main.m
//  appkit-guile
//
//  Created by Paul on 6/9/21.
//

#import <Cocoa/Cocoa.h>
#import <libguile.h>

static void* register_functions (void* data)
{
    scm_display(scm_from_locale_string("guile: Successfully booted.\n"), scm_current_output_port());
    return NULL;
}

int main(int argc, const char * argv[]) {
    scm_init_guile();
    scm_with_guile(&register_functions, NULL);
    return NSApplicationMain(argc, argv);
}
