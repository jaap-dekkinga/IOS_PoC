//
//  AppDelegate.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 1/30/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	// static
	static let audioMatcher = AudioMatcher()

	static var recordingFolderURL: URL {
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		return documentsDirectory.appendingPathComponent("Recordings/")
	}

	// public
	var window: UIWindow?

	// private
	fileprivate var bgTask = UIBackgroundTaskIdentifier.invalid
	fileprivate static let notify = Notify()
	fileprivate weak var swipeVC: SwipeCardActionViewController?

	// MARK: -

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
	{
		// prepare the recordings folder
		prepareRecordingsFolder()

		// setup the audio matcher
		AppDelegate.audioMatcher.delegate = AppDelegate.notify

		DispatchQueue.main.async {
			self.enterForeground(application)
		}

		return true
	}

	func applicationWillResignActive(_ application: UIApplication)
	{
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication)
	{
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		enterBackground(application)
	}

	func applicationWillEnterForeground(_ application: UIApplication)
	{
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
		enterForeground(application)
	}

	func applicationDidBecomeActive(_ application: UIApplication)
	{
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
		becomeActive(application)
	}

	func applicationWillTerminate(_ application: UIApplication)
	{
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

	// MARK: -
	// MARK: Private

	private func prepareRecordingsFolder()
	{
		let fileManager = FileManager.default
		let folderURL = AppDelegate.recordingFolderURL

		// make sure the folder exists
		_ = try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

		// delete every file in the folder
		if let folderContents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: []) {
			for fileURL in folderContents {
				_ = try? fileManager.removeItem(at: fileURL)
			}
		}
	}

	private func stopBackgroundTask(_ application: UIApplication)
	{
		if bgTask != UIBackgroundTaskIdentifier.invalid {
			application.endBackgroundTask(bgTask)
			bgTask = UIBackgroundTaskIdentifier.invalid
		}
	}

	private func enterBackground(_ application: UIApplication)
	{
		bgTask = application.beginBackgroundTask {
			print("bg task ended")
			self.stopBackgroundTask(application)
		}
	}

	private func enterForeground(_ application: UIApplication)
	{
		stopBackgroundTask(application)
	}

	private func becomeActive(_ application: UIApplication)
	{
		AppDelegate.notify.requestPermissionForNotifications()
		AppDelegate.notify.delegate = self
		AppDelegate.audioMatcher.start()
	}

	// MARK: -

	func openPoll(with item: MatchedItem)
	{
		if let cleanSwipeVC = self.swipeVC {
			cleanSwipeVC.dismiss(animated: false, completion: nil)
		}

		let swipeCardActionViewController = SwipeCardActionViewController.create(with: item)
		self.window?.rootViewController?.present(swipeCardActionViewController, animated: true, completion: {
			self.swipeVC = swipeCardActionViewController
		})
	}

}

extension AppDelegate: NotifyDelegate {

	func notificationSelected(sampleUrl: URL, notificationId: String)
	{
		// TODO: reimplement this!
	}

}
