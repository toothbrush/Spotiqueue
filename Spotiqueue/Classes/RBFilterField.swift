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

    func buildFilter(filterString: String) -> NSPredicate? {
        // If the filter field is blanked, we want to display all items.
        guard !filterString.isEmpty else {
            return nil
        }
        var filter: NSPredicate? = nil

        // We want to do substring matching, unless the user really doesn't want us to.
        var massagedFilterString = filterString
        if massagedFilterString.first != "^" {
            massagedFilterString = ".*" + massagedFilterString
        }
        if massagedFilterString.last != "$" {
            massagedFilterString = massagedFilterString + ".*"
        }

        do {
            // We don't like exceptions, so let's attempt to build the regex before .. using it.  There's likely a more performant way of doing this.  It'd be great to have a version of NSPredicate that throws, but that doesn't appear to exist.
            _ = try NSRegularExpression(pattern: massagedFilterString, options: [])

            // The Predicate Programming Guide: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Predicates/AdditionalChapters/Introduction.html#//apple_ref/doc/uid/TP40001789
            // "[cd]" specifies case and diacritic insensitivity
            filter = NSPredicate(format: "SELF.title MATCHES [cd] %@ || SELF.artist MATCHES [cd] %@ || SELF.album MATCHES [cd] %@",
                                 argumentArray: [massagedFilterString, massagedFilterString, massagedFilterString])
        }
        catch {
            logger.warning("Filter string '\(massagedFilterString)' isn't a valid regex.")
        }

        return filter
    }

    override func textDidChange(_ notification: Notification) {
        // We don't directly build the predicate from the filter string because it's.. subtle.
        AppDelegate.appDelegate().searchResultsArrayController.filterPredicate = buildFilter(filterString: self.stringValue)
        super.textDidChange(notification)
    }
}
