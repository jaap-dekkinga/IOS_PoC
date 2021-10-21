//
//  ListenViewController.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/25/20.
//  Copyright © 2020-2021 TuneURL Inc. All rights reserved.
//


import TuneURL
import UIKit


final class ListenViewController: UIViewController {

	// interface
	@IBOutlet var enableSwitch: UISwitch!

	// MARK: - UIViewController

	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)
		enableSwitch.isOn = TuneURL.Listener.isListening
	}

	// MARK: - Actions

	@IBAction func enableSwitchChanged(_ sender: Any?)
	{
		if (enableSwitch.isOn) {
			AppDelegate.shared.startListening()
		} else {
			AppDelegate.shared.stopListening()
		}
	}

}
