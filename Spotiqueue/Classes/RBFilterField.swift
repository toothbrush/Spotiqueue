//
//  RBFilterField.swift
//  Spotiqueue
//
//  Created by Paul on 2/7/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Cocoa

class RBFilterField: NSTextField {

    enum FilterState {
        case Filtering
        case NoFilter
        case BadFilter
    }

    var filterState: FilterState = .NoFilter

    func clearFilter() {
        self.stringValue = ""
        self.updateFilter()
    }

    func buildFilter(filterString: String) -> NSPredicate? {
        // If the filter field is blanked, we want to display all items.
        guard !filterString.isEmpty else {
            filterState = .NoFilter
            return nil
        }
        var filter: NSPredicate? = nil

        filterState = .Filtering
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
            filterState = .BadFilter
        }

        return filter
    }

    func updateFilter() {
        // We don't directly build the predicate from the filter string because it's.. subtle.
        // also, this "if" is important, because we want to maintain the most recent _non-broken_ filter.
        if self.stringValue.isEmpty {
            filterState = .NoFilter
            AppDelegate.appDelegate().searchResultsArrayController.filterPredicate = nil
        }

        if let newFilter = buildFilter(filterString: self.stringValue) {
            AppDelegate.appDelegate().searchResultsArrayController.filterPredicate = newFilter
        }

        self.drawsBackground = true
        switch filterState {
            case .NoFilter:
                // Reset default appearance
                self.backgroundColor = NSColor.textBackgroundColor
            case .Filtering:
                self.backgroundColor = NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.4)
            case .BadFilter:
                self.backgroundColor = NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.4)
        }
    }

    override func textDidChange(_ notification: Notification) {
        updateFilter()
        super.textDidChange(notification)
    }
}
