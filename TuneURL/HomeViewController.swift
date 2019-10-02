//
//  HomeViewController.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 7/11/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import UIKit


class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

	// interface
	@IBOutlet var enableButton: UIButton!
	@IBOutlet var enableLabel: UILabel!
	@IBOutlet var matchTableView: UITableView!
	@IBOutlet var tooltipLabel: UILabel!

	// interface colors
	private let greenBackOn = UIColor(red: 0.17, green: 0.67, blue: 0.48, alpha: 1.0)
	private let greenBackOff = UIColor(red: 0.17, green: 0.55, blue: 0.40, alpha: 1.0)

	// private
	private let audioMatcher = AppDelegate.audioMatcher
	private let itemCollection = MatchedItemCollection.shared

	// MARK: -

	override func viewDidLoad()
	{
		super.viewDidLoad()
		updateListeningInterface()
	}

	override func viewDidAppear(_ animated: Bool)
	{
		super.viewDidAppear(animated)

		UIView.animate(withDuration: 3.0) {
			self.tooltipLabel.alpha = 0.0
			self.tooltipLabel.textColor = self.greenBackOff
		}

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

		matchTableView.insertRows(at: [IndexPath(row: newItemIndex, section: 0)], with: .top)
	}

	@IBAction func enableButtonPressed(_ sender: UIButton)
	{
		audioMatcher.enabled.toggle()
		updateListeningInterface()
	}

	// MARK: -
	// MARK: Private

	private func buttonGlow(_ button: UIButton, on: Bool)
	{
		if on {
			button.layer.shadowColor = UIColor.cyan.cgColor
		} else {
			button.layer.shadowColor = UIColor.clear.cgColor
		}
		button.layer.shadowRadius = 10.0
		button.layer.shadowOpacity = 1.0
		button.layer.shadowOffset = CGSize.zero
	}

	private func updateListeningInterface()
	{
		if audioMatcher.enabled {
			self.view.backgroundColor = greenBackOn
			self.enableLabel.text = "Listening"
		} else {
			self.view.backgroundColor = greenBackOff
			self.enableLabel.text = "Tap to Listen"
		}
		buttonGlow(self.enableButton, on: audioMatcher.enabled)
	}

	// MARK: -
	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool
	{
		return true
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		let cell = tableView.dequeueReusableCell(withIdentifier: "MatchedItemCell", for: indexPath) as! MatchedItemCell
		cell.item = itemCollection.item(withIndex: indexPath.row)

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
		return itemCollection.count
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

		switch (item.action) {
			case .phoneNumber:
				// open the phone number
				if let phoneURL = item.phoneURL {
					UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
				}
			case .poll:
				// open the poll
				if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
					appDelegate.openPoll(with: item)
				}
			case .webPage:
				// open the web page
				if let itemURL = item.url {
					UIApplication.shared.open(itemURL, options: [:], completionHandler: nil)
				}
			default:
				break
		}
	}

}
