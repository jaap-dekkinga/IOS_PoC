//
//  SavedContentViewController.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/25/20.
//  Copyright © 2020 TuneURL Inc. All rights reserved.
//


import UIKit


final class SavedContentViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

	// interface
	@IBOutlet var previousCollectionView: UICollectionView!
	@IBOutlet var recentCollectionView: UICollectionView!

	// private
	private let itemCollection = MatchedItemCollection.shared
	private let maxRecentCount = 5
    
    //reporting
    private let reportingManager = ReportingManager ()


	// MARK: -

	override func viewDidAppear(_ animated: Bool)
	{
		super.viewDidAppear(animated)

		// reload the collection
		previousCollectionView.reloadData()
		recentCollectionView.reloadData()

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
			recentCollectionView.reloadData()
			return
		}

		// add the item to the table view if the table is displaying 'recents'
		recentCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])

		// open polls when they are matched
		if let item = itemCollection.item(withIndex: newItemIndex) {
			if (item.action == .poll) {
				openItem(item)
			}
		}
	}

	@IBAction func collectionChanged(_ sender: Any?)
	{
		previousCollectionView.reloadData()
		recentCollectionView.reloadData()
	}

	// MARK: -
	// MARK: Private

	private func openItem(_ item: MatchedItem, wasUserInitiated: Bool = false)
	{
        //reporting
        reportingManager.captureUserAction(for: item, InterestAction: "interested")
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
	// MARK: UICollectionViewDataSource

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
	{
		// get the matched item
		var item: MatchedItem?

		if (collectionView === recentCollectionView) {
			item = itemCollection.recentItem(withIndex: indexPath.row)
		} else {
			item = itemCollection.item(withIndex: indexPath.row)
		}

		// get the item cell
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MatchedItemCell", for: indexPath) as! MatchedItemCell
		cell.item = item

		return cell
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
	{
		if (collectionView === recentCollectionView) {
			return itemCollection.recentCount
		} else {
			return itemCollection.count
		}
	}

	// MARK: -
	// MARK: UICollectionViewDelegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
	{
		// deselect the item
		collectionView.deselectItem(at: indexPath, animated: true)

		// get the selected item cell
		guard let cell = collectionView.cellForItem(at: indexPath) as? MatchedItemCell else {
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
