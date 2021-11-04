//
//  MatchedItemCollection.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/22/19.
//  Copyright © 2019-2021 TuneURL Inc. All rights reserved.
//


import Foundation
import TuneURL


let MatchedItemCollectionAddedItemNotification = Notification.Name("MatchedItemCollectionAddedItemNotification")


class MatchedItemCollection {

	// static
	static let shared = MatchedItemCollection()

	// maximum time to keep recent items (24 hours)
	let recentItemMaxTime = (24.0 * 60.0 * 60.0)

	// public
	var count: Int {
		return collectionItems.count
	}

	// private
	private let collectionFileURL: URL
	private var collectionItems = [MatchedItem]()

	// MARK: -

	init()
	{
		// setup the collection file url
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		collectionFileURL = documentsDirectory.appendingPathComponent("MatchCollection.plist")

		// load the saved matched items
		reloadItems()
	}

	// MARK: -

	func addItem(with match: Match) -> MatchedItem?
	{
		// add the item to the collection
		let matchedItem = MatchedItem(with: match)
		collectionItems.insert(matchedItem, at: 0)
		saveItems()

		// notify observers an item was added
		NotificationCenter.default.post(name: MatchedItemCollectionAddedItemNotification, object: self, userInfo: [ "Item Index" : 0 ])

		return matchedItem
	}

	func removeItem(_ item: MatchedItem) -> Bool
	{
		let startCount = collectionItems.count
		collectionItems.removeAll(where: { $0 === item })
		if (collectionItems.count < startCount) {
			saveItems()
			return true
		}

		return false
	}

	func item(withIndex index: Int) -> MatchedItem?
	{
		// safety check
		guard (index >= 0), (index < collectionItems.count) else {
			return nil
		}

		return collectionItems[index]
	}

	// MARK: - Favorite Items

	var favoriteCount: Int {
		var count = 0
		for item in collectionItems {
			if item.favorite {
				count += 1
			}
		}
		return count
	}

	func favoriteItem(withIndex index: Int) -> MatchedItem?
	{
		// safety check
		guard (index >= 0), (index < collectionItems.count) else {
			return nil
		}

		var currentIndex = 0

		for item in collectionItems {
			if item.favorite {
				if (currentIndex == index) {
					return item
				}
				currentIndex += 1
			}
		}

		return nil
	}

	func setFavorite(_ favorite: Bool, for item: MatchedItem)
	{
		guard item.favorite != favorite else {
			return
		}

		item.favorite = favorite
		saveItems()
	}

	// MARK: - Recent Items

	private func itemIsRecent(_ item: MatchedItem) -> Bool
	{
		let timeSinceMatch = abs(item.matchedTime.timeIntervalSinceNow)
		return (timeSinceMatch <= recentItemMaxTime)
	}

	private func pruneRecentItems()
	{
		var index = collectionItems.count

		while (index > 0) {
			let item = collectionItems[(index - 1)]
			if ((item.favorite == false) && (itemIsRecent(item) == false)) {
				collectionItems.remove(at: (index - 1))
			}
			index -= 1
		}
	}

	var recentCount: Int {
		var count = 0
		for item in collectionItems {
			if itemIsRecent(item) {
				count += 1
			}
		}
		return count
	}

	func recentItem(withIndex index: Int) -> MatchedItem?
	{
		// safety check
		guard (index >= 0), (index < collectionItems.count) else {
			return nil
		}

		var currentIndex = 0

		for item in collectionItems {
			if itemIsRecent(item) {
				if (currentIndex == index) {
					return item
				}
				currentIndex += 1
			}
		}

		return nil
	}

	// MARK: - Private

	private func reloadItems()
	{
		// load the collection file
		guard let collectionData = try? Data(contentsOf: collectionFileURL) else {
			return
		}

		// decode the saved items
		let decoder = PropertyListDecoder()
		guard let decodedItems = try? decoder.decode([MatchedItem].self, from: collectionData) else {
			NSLog("MatchedItemCollection: Error decoding saved items file.")
			return
		}

		// set the items
		collectionItems = decodedItems

		// prune no longer recent items
		pruneRecentItems()
	}

	private func saveItems()
	{
		do {
			// encode the matched items
			let encoder = PropertyListEncoder()
			let collectionData = try encoder.encode(collectionItems)
			try collectionData.write(to: collectionFileURL)
		} catch {
			NSLog("MatchedItemCollection: Error encoding collection file. (\(error.localizedDescription))")
		}
	}

}
