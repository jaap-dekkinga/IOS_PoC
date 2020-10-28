//
//  UIViewExtensions.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/28/20.
//  Copyright © 2020 TuneURL Inc. All rights reserved.
//


import UIKit


extension UIView {

	@IBInspectable var CornerRadius: CGFloat {
		get {
			return self.layer.cornerRadius
		}
		set {
			self.layer.cornerRadius = newValue
			self.layer.masksToBounds = newValue > 0
		}
	}

	@IBInspectable var BorderColor: UIColor? {
		get {
			if let color = self.layer.borderColor {
				return UIColor(cgColor: color)
			}
			return nil
		}
		set {
			self.layer.borderColor = newValue?.cgColor
		}
	}

	@IBInspectable var BorderWidth: CGFloat {
		get {
			return self.layer.borderWidth
		}
		set {
			self.layer.borderWidth = newValue
		}
	}

}
