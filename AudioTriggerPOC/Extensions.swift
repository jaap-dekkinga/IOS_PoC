//
//  Extensions.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

extension UserDefaults {
    var emailDestination: String? {
        get { return string(forKey: #function) }
        set { set(newValue, forKey: #function) }
    }
}

extension UIColor {
    convenience init(rgb: Int, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    struct AudioTrigger {
        static var error: UIColor {
            return UIColor(red: 252.0/255.0, green: 66.0/255.0, blue: 54.0/255.0, alpha: 1.0)
        }

        static var valid: UIColor {
            return UIColor(red: 86.0/255.0, green: 216.0/255.0, blue: 118.0/255.0, alpha: 1.0)
        }
    }
}

