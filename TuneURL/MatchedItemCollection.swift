//
//  MatchedItemCollection.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/22/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


let MatchedItemCollectionChangedNotification = Notification.Name("MatchedItemCollectionChangedNotification")


class MatchedItemCollection {

	// static
	static let shared = MatchedItemCollection()

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

	func addItem(with sampleData: SampleData)
	{
		// add the item to the collection
		collectionItems.insert(MatchedItem(with: sampleData), at: 0)
		saveItems()

		// notify observers the collection changed
		NotificationCenter.default.post(name: MatchedItemCollectionChangedNotification, object: self)
	}

	func item(withIndex index: Int) -> MatchedItem?
	{
		// safety check
		if ((index < 0) || (index >= collectionItems.count)) {
			return nil
		}

		return collectionItems[index]
	}

	// MARK: -
	// MARK: Private

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
