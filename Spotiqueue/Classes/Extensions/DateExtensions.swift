//
//  DateExtensions.swift
//  Spotiqueue
//
//  Created by Paul on 13/9/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

extension Date {
    // Inspiration: https://stackoverflow.com/questions/28332946/how-do-i-get-the-current-date-in-short-format-in-swift
    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}
