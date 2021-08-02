//
//  AppDelegate.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 1/30/18.
//  Copyright © 2018-2021 TuneURL Inc. All rights reserved.
//


import UIKit
import Speech


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, AudioMatcherDelegate {

	// static
	static let audioMatcher = AudioMatcher()
    private let itemCollection = MatchedItemCollection.shared

	static var recordingFolderURL: URL {
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		return documentsDirectory.appendingPathComponent("Recordings/")
	}

	// public
	var window: UIWindow?

	// private
	fileprivate var backgroundTask = UIBackgroundTaskIdentifier.invalid
	fileprivate static let notify = Notify()
	fileprivate weak var pollViewController: PollViewController?
    fileprivate weak var interestViewController: InterestViewController?

    // reporting init
    private var matchedItem: MatchedItem?
    private let reportingManager = ReportingManager ()

	// MARK: -

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
	{
		// prepare the recordings folder
		prepareRecordingsFolder()

		// setup the audio matcher
		AppDelegate.audioMatcher.delegate = self

		DispatchQueue.main.async {
			self.enterForeground(application)
		}

		// request speech recognition permission on launch
		SFSpeechRecognizer.requestAuthorization {
			authStatus in
		}
        
        NotificationCenter.default.addObserver(self, selector: #selector(collectionAddedItem), name: MatchedItemCollectionAddedItemNotification, object: itemCollection)

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
		if (backgroundTask != .invalid) {
			application.endBackgroundTask(backgroundTask)
			backgroundTask = .invalid
		}
	}

	private func enterBackground(_ application: UIApplication)
	{
		backgroundTask = application.beginBackgroundTask {
			self.stopBackgroundTask(application)
		}
	}

	private func enterForeground(_ application: UIApplication)
	{
		stopBackgroundTask(application)
        
        // watch for collection changes
        
	}

	private func becomeActive(_ application: UIApplication)
	{
		AppDelegate.notify.requestPermissionForNotifications()
		AppDelegate.notify.delegate = self
		AppDelegate.audioMatcher.start()
	}

	// MARK: -

	func audioMatched(_ matchResponse: SampleData)
	{
		// ignore matches with extremely low confidence
		guard (matchResponse.confidence > 1) else {
			return
		}

		// audio was successfully matched
		if let matchedItem = MatchedItemCollection.shared.addItem(with: matchResponse) {
			AppDelegate.notify.notifyMatch(matchedItem)
            reportingManager.captureUserAction(for: matchedItem, InterestAction: "heard")

		}
	}

    @objc func collectionAddedItem(_ notification: Notification)
    {
        guard let newItemIndex = notification.userInfo?["Item Index"] as? Int else {
            //recentCollectionView.reloadData()
            return
        }

        // add the item to the table view if the table is displaying 'recents'
        //recentCollectionView.insertItems(at: [IndexPath(item: 0, section: 0)])

        // open polls when they are matched, ask if interested for everything else
        if let item = itemCollection.item(withIndex: newItemIndex) {
            if (item.action == .poll) { // Open right away
                openPoll(with: item, wasUserInitiated: false)
            } else { // Ask if interested
                // dismiss any previous view controller
                interestViewController?.dismiss(animated: false, completion: nil)
                interestViewController = nil

                // open the poll view controller
                let viewController = InterestViewController.create(with: item, wasUserInitiated: false)
                self.window?.rootViewController?.present(viewController, animated: true)
                interestViewController = viewController
            }
        }  
    }

    
    
	func openPoll(with item: MatchedItem, wasUserInitiated: Bool)
	{
		// dismiss any previous view controller
		pollViewController?.dismiss(animated: false, completion: nil)
		pollViewController = nil

		// open the poll view controller
		let viewController = PollViewController.create(with: item, wasUserInitiated: wasUserInitiated)
		self.window?.rootViewController?.present(viewController, animated: true)
		pollViewController = viewController
	}

}

extension AppDelegate: NotifyDelegate {

	func notificationSelected(sampleUrl: URL, notificationId: String)
	{
		// TODO: reimplement this!
	}

}
