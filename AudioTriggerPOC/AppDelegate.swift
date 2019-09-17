//
//  AppDelegate.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//


import UIKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	// static
	static let audioMatcher = AudioMatcher()

	// public
	var window: UIWindow?

	// private
	fileprivate var bgTask = UIBackgroundTaskIdentifier.invalid
	fileprivate static let notify = Notify()
	fileprivate weak var swipeVC: SwipeCardActionViewController?

	// MARK: -

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
	{
		// Override point for customization after application launch.
		firstStart(application)
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

}

extension AppDelegate {

	fileprivate func stopBackgroundTask(_ application: UIApplication)
	{
		if bgTask != UIBackgroundTaskIdentifier.invalid {
			application.endBackgroundTask(bgTask)
			bgTask = UIBackgroundTaskIdentifier.invalid
		}
	}

	fileprivate func firstStart(_ application: UIApplication)
	{
		AppDelegate.audioMatcher.delegate = AppDelegate.notify
		DispatchQueue.main.async {
			self.enterForeground(application)
		}
	}

	fileprivate func enterBackground(_ application: UIApplication)
	{
		bgTask = application.beginBackgroundTask {
			print("bg task ended")
			self.stopBackgroundTask(application)
		}
	}

	fileprivate func enterForeground(_ application: UIApplication)
	{
		stopBackgroundTask(application)
	}

	fileprivate func becomeActive(_ application: UIApplication)
	{
		AppDelegate.notify.requestPermissionForNotifications()
		AppDelegate.notify.delegate = self
		AppDelegate.audioMatcher.start()
	}

}

extension AppDelegate: NotifyDelegate {

	func notificationSelected(sampleUrl: URL, notificationId: String)
	{
		if let cleanSwipeVC = self.swipeVC {
			cleanSwipeVC.dismiss(animated: false, completion: nil)
		}

		let swipeCardActionViewController = SwipeCardActionViewController.create(with: sampleUrl)
		self.window?.rootViewController?.present(swipeCardActionViewController, animated: true, completion: {
			self.swipeVC = swipeCardActionViewController
		})
	}

}
