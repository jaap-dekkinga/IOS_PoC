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
	@IBOutlet weak var titleLabel: UILabel!

	// public
	var item: MatchedItem? {
		didSet {
			if let matchedItem = self.item {
				titleLabel.text = matchedItem.title
			} else {
				titleLabel.text = ""
			}
		}
	}

}
