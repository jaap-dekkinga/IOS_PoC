//
//  Box.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-11-13.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation

class Box<T>: NSObject where T: Hashable & Equatable {
    let value: T

    init(_ value: T) {
        self.value = value
    }

    // In order to make it possible to be used as key in NSCache
    // it must inherit from NSObject and override isEqual, hash.
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Box else {
            return false
        }

        return other.value == self.value
    }

    override var hash: Int {
        return value.hashValue
    }
}
