//
//  SavedContentViewController.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/25/20.
//  Copyright © 2020 TuneURL Inc. All rights reserved.
//


import UIKit


final class SavedContentViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

	// interface
	@IBOutlet var collectionSelector: UISegmentedControl!
	@IBOutlet var matchTableView: UITableView!

	// private
	private let itemCollection = MatchedItemCollection.shared

	// MARK: -

	override func viewDidLoad()
	{
		super.viewDidLoad()
		collectionSelector.selectedSegmentIndex = 0
	}

	override func viewDidAppear(_ animated: Bool)
	{
		super.viewDidAppear(animated)

		// reload the collection
		matchTableView.reloadData()

		// watch for collection changes
		NotificationCenter.default.addObserver(self, selector: #selector(collectionAddedItem), name: MatchedItemCollectionAddedItemNotification, object: itemCollection)
	}

	override func viewWillDisappear(_ animated: Bool)
	{
		// stop watching collection changes
		NotificationCenter.default.removeObserver(self)

		super.viewWillDisappear(animated)
	}

	@objc func collectionAddedItem(_ notification: Notification)
	{
		guard let newItemIndex = notification.userInfo?["Item Index"] as? Int else {
			matchTableView.reloadData()
			return
		}

		// add the item to the table view if the table is displaying 'recents'
		if (collectionSelector.selectedSegmentIndex == 0) {
			matchTableView.insertRows(at: [IndexPath(row: newItemIndex, section: 0)], with: .top)
		}

		// open polls when they are matched
		if let item = itemCollection.item(withIndex: newItemIndex) {
			if (item.action == .poll) {
				openItem(item)
			}
		}
	}

	@IBAction func collectionChanged(_ sender: Any?)
	{
		matchTableView.reloadData()
	}

	// MARK: -
	// MARK: Private

	private func openItem(_ item: MatchedItem, wasUserInitiated: Bool = false)
	{
		switch (item.action) {
			case .phoneNumber:
				// open the phone number
				if let phoneURL = item.phoneURL {
					UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
				}
			case .poll:
				// open the poll
				if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
					appDelegate.openPoll(with: item, wasUserInitiated: wasUserInitiated)
				}
			case .coupon, .webPage:
				// open the url
				if let itemURL = item.url {
					UIApplication.shared.open(itemURL, options: [:], completionHandler: nil)
				}
			default:
				break
		}
	}

	// MARK: -
	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
	{
		return true
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		// get the matched item
		var item: MatchedItem?
		switch collectionSelector.selectedSegmentIndex {
			case 0:
				item = itemCollection.recentItem(withIndex: indexPath.row)
			case 1:
				item = itemCollection.favoriteItem(withIndex: indexPath.row)
			default:
				item = itemCollection.item(withIndex: indexPath.row)
		}

		// get the item cell
		let cell = tableView.dequeueReusableCell(withIdentifier: "MatchedItemCell", for: indexPath) as! MatchedItemCell
		cell.item = item

		return cell
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath)
	{
		if (editingStyle == .delete) {
			// delete the item from the collection
			if let cell = matchTableView.cellForRow(at: indexPath) as? MatchedItemCell {
				if let item = cell.item {
					if (itemCollection.removeItem(item) == true) {
						matchTableView.deleteRows(at: [indexPath], with: .left)
					}
				}
			}
		}
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
		switch collectionSelector.selectedSegmentIndex {
			case 0:
				return itemCollection.recentCount
			case 1:
				return itemCollection.favoriteCount
			default:
				return itemCollection.count
		}
	}

	func numberOfSections(in tableView: UITableView) -> Int
	{
		return 1
	}

	// MARK: -
	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
	{
		// deselect the row
		matchTableView.deselectRow(at: indexPath, animated: true)

		// get the selected item cell
		guard let cell = matchTableView.cellForRow(at: indexPath) as? MatchedItemCell else {
			return
		}

		// get the item from the cell
		guard let item = cell.item else {
			return
		}

		// open the item
		openItem(item, wasUserInitiated: true)
	}

}
