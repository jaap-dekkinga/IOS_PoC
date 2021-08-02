//
//  SavedItemCollectionLayout.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/28/20.
//  Copyright © 2020-2021 TuneURL Inc. All rights reserved.
//


import UIKit


final class SavedItemCollectionLayout: UICollectionViewFlowLayout {

	// private
	private let aspectRatio: CGFloat = (3.0 / 4.0)
	private let itemSpacing: CGFloat = 16.0
	private let smallestItemWidth: CGFloat = 180

	// MARK: -

	override func prepare()
	{
		super.prepare()

		guard let viewWidth = self.collectionView?.bounds.size.width else {
			return
		}

		// recalculate the number of items per line
		var itemsPerLine = 1
		var currentWidth = (viewWidth - smallestItemWidth)
		while (currentWidth > 0) {
			itemsPerLine += 1
			currentWidth -= smallestItemWidth
			currentWidth -= itemSpacing
		}

		// recalculate the item size
		let spaceForItems = (viewWidth - (CGFloat(itemsPerLine - 1) * itemSpacing))
		let itemWidth = (spaceForItems / CGFloat(itemsPerLine))
		let itemHeight = (itemWidth * aspectRatio)
		self.itemSize = CGSize(width: itemWidth, height: itemHeight)

		// recalculate the item spacing
//		let emptySpaceWidth = (viewWidth - (itemWidth * CGFloat(itemsPerLine)))
//		let itemHorizontalSpacing = (emptySpaceWidth / CGFloat(itemsPerLine + 1))
//		let itemVerticalSpacing = (itemHorizontalSpacing * 0.70)
//		let cellInsets = UIEdgeInsets(top: (marginWidth / 2.0), left: (marginWidth / 2.0), bottom: (marginWidth / 2.0), right: (marginWidth / 2.0))
//		let cellInsets = UIEdgeInsets(top: itemVerticalSpacing, left: itemHorizontalSpacing, bottom: itemVerticalSpacing, right: itemHorizontalSpacing)
//		self.minimumLineSpacing = itemVerticalSpacing
		self.minimumInteritemSpacing = itemSpacing
		self.minimumLineSpacing = itemSpacing
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

	override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint
	{
		// TODO: Fix the offset after rotation...
		return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
	}

}
