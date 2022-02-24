//
//  RecentItemCollectionLayout.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/28/20.
//  Copyright © 2020-2022 TuneURL Inc. All rights reserved.
//


import UIKit


final class RecentItemCollectionLayout: UICollectionViewFlowLayout {

	// private
	private let aspectRatio: CGFloat = (3.0 / 4.0)
	private let itemSpacing: CGFloat = 16.0
//	private let smallestItemWidth: CGFloat = 180

	// MARK: -

	override func prepare()
	{
		super.prepare()

		guard let viewSize = self.collectionView?.bounds.size else {
			return
		}

		// calculate the item size
		let itemSize: CGSize
		if ((viewSize.height / viewSize.width) <= aspectRatio) {
			// height based
			itemSize = CGSize(width: (viewSize.height / aspectRatio), height: viewSize.height)
		} else {
			itemSize = CGSize(width: viewSize.width, height: (viewSize.width * aspectRatio))
		}
		self.itemSize = itemSize

		// recalculate the item insets
		let horizontalInset = ((viewSize.width - itemSize.width) / 2.0)
		let verticalInset = ((viewSize.height - itemSize.height) / 2.0)
		let cellInsets = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
		self.sectionInset = cellInsets

		// recalculate the item spacing
		self.minimumInteritemSpacing = itemSpacing
		self.minimumLineSpacing = itemSpacing

//		let emptySpaceWidth = (viewWidth - (itemWidth * CGFloat(itemsPerLine)))
//		let itemHorizontalSpacing = (emptySpaceWidth / CGFloat(itemsPerLine + 1))
//		let itemVerticalSpacing = (itemHorizontalSpacing * 0.70)
//		let cellInsets = UIEdgeInsets(top: (marginWidth / 2.0), left: (marginWidth / 2.0), bottom: (marginWidth / 2.0), right: (marginWidth / 2.0))
//		let cellInsets = UIEdgeInsets(top: itemVerticalSpacing, left: itemHorizontalSpacing, bottom: itemVerticalSpacing, right: itemHorizontalSpacing)
//		self.minimumLineSpacing = itemVerticalSpacing
//		self.sectionInset = cellInsets
	}

	override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool
	{
		if let oldBounds = self.collectionView?.bounds {
			var shouldInvalidate = true

			if (oldBounds.size.width == newBounds.size.width) {
				shouldInvalidate = false
			}

			return shouldInvalidate
		}

		return true
	}

}
