//
//  OptionSetExtensions.swift
//  Spotiqueue
//
//  Created by paul david on 31/5/21.
//  Copyright © 2021 Rustling Broccoli. All rights reserved.
//

import Foundation

// from https://stackoverflow.com/questions/32102936/how-do-you-enumerate-optionsettype-in-swift
public extension OptionSet where RawValue: FixedWidthInteger {
    func elements() -> AnySequence<Self> {
        var remainingBits = rawValue
        var bitMask: RawValue = 1
        return AnySequence {
            AnyIterator {
                while remainingBits != 0 {
                    defer { bitMask = bitMask &* 2 }
                    if remainingBits & bitMask != 0 {
                        remainingBits = remainingBits & ~bitMask
                        return Self(rawValue: bitMask)
                    }
                }
                return nil
            }
        }
    }
}
