//
//  ListenViewController.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/25/20.
//  Copyright © 2020 TuneURL Inc. All rights reserved.
//


import UIKit


final class ListenViewController: UIViewController {

	// interface
	@IBOutlet var enableSwitch: UISwitch!

	// private
	private let audioMatcher = AppDelegate.audioMatcher

	// MARK: -
	// MARK: UIViewController

	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
		enableSwitch.isOn = audioMatcher.enabled
	}

	// MARK: -
	// MARK: Actions

	@IBAction func enableSwitchChanged(_ sender: Any?)
	{
		audioMatcher.enabled = enableSwitch.isOn
	}

}
