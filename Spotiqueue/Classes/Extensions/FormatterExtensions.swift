//
//  FormatterExtensions.swift
//  Spotiqueue
//
//  Created by Paul on 29/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

// Inspiration from https://stackoverflow.com/questions/54641424/swift-datecomponentsformatter-drop-leading-zeroes-but-keep-at-least-one-digit-in
extension Formatter {
    static let positional: DateComponentsFormatter = {
        let positional = DateComponentsFormatter()
        positional.maximumUnitCount = 0
        positional.unitsStyle = .positional
        positional.zeroFormattingBehavior = .pad
        return positional
    }()
}
