//
//  MatchedItemCell.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/22/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import UIKit


class MatchedItemCell: UICollectionViewCell {

	// interface
	@IBOutlet weak var thumbnailImage: UIImageView!
	@IBOutlet weak var sourceLabel: UILabel!
	@IBOutlet weak var titleLabel: UILabel!

	// public
	var item: MatchedItem? {
		didSet {
			// check that we have a valid item
			guard let matchedItem = self.item else {
				thumbnailImage.image = nil
				titleLabel.text = ""
				return
			}

			// update the thumbnail image
			var image: UIImage?
			switch matchedItem.action {
				case .coupon:
					image = UIImage(named: "Matched-Item-Coupon")
				case .phoneNumber:
					image = UIImage(named: "Matched-Item-Phone")
				case .poll:
					image = UIImage(named: "Matched-Item-Poll")
				case .webPage:
					image = UIImage(named: "Matched-Item-Web")
				default:
					break
			}
			thumbnailImage.image = image

			// update the item title
			titleLabel.text = matchedItem.title
		}
	}

}
