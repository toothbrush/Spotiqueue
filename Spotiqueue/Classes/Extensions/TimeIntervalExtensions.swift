//
//  TimeIntervalExtensions.swift
//  Spotiqueue
//
//  Created by Paul on 29/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

extension TimeInterval {
    var positionalTime: String {
        if self == 0 {
            return "-:--"
        }

        // always show at least minutes and seconds.
        Formatter.positional.allowedUnits = self >= 3600 ?
            [.hour, .minute, .second] :
            [.minute, .second]
        let string = Formatter.positional.string(from: self)!
        return string.hasPrefix("0") ?
            .init(string.dropFirst()) :
            string
    }
}
