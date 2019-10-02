//
//  MatchedItemCell.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/22/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import UIKit


class MatchedItemCell: UITableViewCell {

	// interface
	@IBOutlet weak var favoriteButton: UIButton!
	@IBOutlet weak var iconImage: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!

	// public
	var item: MatchedItem? {
		didSet {
			// check that we have a valid item
			guard let matchedItem = self.item else {
				favoriteButton.isHidden = true
				iconImage.image = nil
				titleLabel.text = ""
				return
			}

			// update the icon image
			var image: UIImage?
			switch matchedItem.action {
				case .phoneNumber:
					image = UIImage(named: "Matched-Item-Phone")
				case .poll:
					image = UIImage(named: "Matched-Item-Poll")
				case .webPage:
					image = UIImage(named: "Matched-Item-Web")
				default:
					break
			}
			iconImage.image = image

			// update the item title
			titleLabel.text = matchedItem.title

			// update the favorite button
			updateFavoriteButton()
		}
	}

	// MARK: -

	@IBAction func favoriteItem(_ sender: Any?)
	{
		if let matchedItem = self.item {
			MatchedItemCollection.shared.setItem(matchedItem, favorite: !matchedItem.favorite)
			updateFavoriteButton()
		}
	}

	// MARK: -

	private func updateFavoriteButton()
	{
		if let matchedItem = self.item {
			let favoriteImageName = (matchedItem.favorite) ? "Matched-Item-Favorite" : "Matched-Item-Favorite-Empty"
			favoriteButton.setImage(UIImage(named: favoriteImageName), for: .normal)
			favoriteButton.isHidden = false
		} else {
			favoriteButton.isHidden = true
		}
	}

}
