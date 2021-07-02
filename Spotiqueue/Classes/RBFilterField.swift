//
//  RBFilterField.swift
//  Spotiqueue
//
//  Created by Paul on 2/7/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBFilterField: NSTextField {

    func focusSearchTable() {
        AppDelegate.appDelegate().window.makeFirstResponder(AppDelegate.appDelegate().searchTableView)
    }

    override func keyDown(with event: NSEvent) {
        // You might wonder why i don't deal with Esc and Enter here.  Esc is dealt with in AppDelegate (because unless the filter is selected, it cancels pending searches) and Enter is fired by the action hooked up in Interface Builder from this field.  Also, it could've been better to use "nextResponder" or whatever, but that's a finicky nightmare in IB.  I tried, and it broke the initial focus on the search field, so let's just do what works.  I probably need tests around this...
        if event.keyCode == kVK_Tab {
            focusSearchTable()
        } else {
            super.keyDown(with: event)
        }
    }

}
