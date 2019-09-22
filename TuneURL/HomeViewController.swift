//
//  HomeViewController.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 7/11/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import UIKit


class HomeViewController: UIViewController, UITableViewDataSource {

	// interface
	@IBOutlet var enableButton: UIButton!
	@IBOutlet var enableLabel: UILabel!
	@IBOutlet var matchTableView: UITableView!
	@IBOutlet var tooltipLabel: UILabel!

	fileprivate let vm = HomeViewModel()
	fileprivate let greenBackOn = UIColor(red: 0.17, green: 0.67, blue: 0.48, alpha: 1.00)
	fileprivate let greenBackOff = UIColor(red: 0.17, green: 0.55, blue: 0.40, alpha: 1.00)

	// private
	private let itemCollection = MatchedItemCollection.shared

	// MARK: -

	override func viewDidLoad()
	{
		super.viewDidLoad()
		self.refreshScreen()
	}

	override func viewDidAppear(_ animated: Bool)
	{
		super.viewDidAppear(animated)

		UIView.animate(withDuration: 3.0) {
			self.tooltipLabel.alpha = 0.0
			self.tooltipLabel.textColor = self.greenBackOff
		}

		// watch for collection changes
		NotificationCenter.default.addObserver(self, selector: #selector(collectionChanged), name: MatchedItemCollectionChangedNotification, object: itemCollection)
	}

	override func viewWillDisappear(_ animated: Bool)
	{
		// stop watching collection changes
		NotificationCenter.default.removeObserver(self)

		super.viewWillDisappear(animated)
	}

	@IBAction func enableButtonPressed(_ sender: UIButton)
	{
		self.vm.isButtonOn.toggle()
		refreshScreen() //TODO: Move this in feedback loop form VM (delegate)
	}

	private func refreshScreen()
	{
		if self.vm.isButtonOn {
			self.view.backgroundColor = greenBackOn
			self.enableLabel.text = "On"
		} else {
			self.view.backgroundColor = greenBackOff
			self.enableLabel.text = "Off"
		}
		buttonGlow(self.enableButton, on: self.vm.isButtonOn)
	}

	private func buttonGlow(_ button: UIButton, on: Bool)
	{
		if on {
			button.layer.shadowColor = UIColor.cyan.cgColor
		} else {
			button.layer.shadowColor = UIColor.clear.cgColor
		}
		button.layer.shadowRadius = 10.0;
		button.layer.shadowOpacity = 1.0;
		button.layer.shadowOffset = CGSize.zero;
	}

	@objc func collectionChanged(_ : Any?)
	{
		matchTableView.reloadData()
	}

	// MARK: -
	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
	{
		let cell = tableView.dequeueReusableCell(withIdentifier: "MatchedItemCell", for: indexPath) as! MatchedItemCell
		cell.item = itemCollection.item(withIndex: indexPath.row)

		return cell
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
	{
		return itemCollection.count
	}

	func numberOfSections(in tableView: UITableView) -> Int
	{
		return 1
	}

}

// MARK: -

class HomeViewModel {

	private let audioMatcher = AppDelegate.audioMatcher //TODO: Inject

	var isButtonOn: Bool {
		get { return self.audioMatcher.enabled }
		set { self.audioMatcher.enabled = newValue }
	}

}
