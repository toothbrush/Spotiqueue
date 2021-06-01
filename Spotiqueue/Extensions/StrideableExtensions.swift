//
//  StrideableExtensions.swift
//  Spotiqueue
//
//  Created by paul david on 1/6/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

// stolen from https://stackoverflow.com/questions/36110620/standard-way-to-clamp-a-number-between-two-values-in-swift
extension Strideable where Stride: SignedInteger {
    func clamped(to limits: CountableClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
    
    func clamped(to limits: CountableRange<Self>) -> Self {
        // There's a "minus one" in here, because with an open range, the range actually isn't meant to contain its upper bound.  So when using this for an array lookup, we need to take our upper bound less one.
        return min(max(self, limits.lowerBound), limits.upperBound.advanced(by: -1))
    }
}
