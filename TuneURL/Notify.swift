//
//  Notify.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 3/4/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import UIKit
import UserNotifications


protocol NotifyDelegate {
	func notificationSelected(sampleUrl: URL, notificationId: String)
}

class Notify: NSObject {

	fileprivate enum Config {
		static let sampleUrlKey = "sampleUrl"
		static let saveCategory = "saveCategory"
		static let saveCategoryActions: [UNNotificationAction] = []
	}

	fileprivate let userNotifyOptions: UNAuthorizationOptions = [.alert, .sound]
	fileprivate let userCenter = UNUserNotificationCenter.current()
	fileprivate(set) var isEnabled = false
	fileprivate let saveCategory = UNNotificationCategory(identifier: Config.saveCategory, actions: [], intentIdentifiers: [], options: .customDismissAction)

	var delegate: NotifyDelegate?

	// MARK: -

	override init()
	{
		super.init()
		self.updateEnabledStatus()
		self.userCenter.setNotificationCategories([self.saveCategory])
		self.userCenter.delegate = self
	}

	private func updateEnabledStatus()
	{
		self.userCenter.getNotificationSettings { (settings) in
			self.isEnabled = settings.authorizationStatus == .authorized && settings.alertStyle != .none
		}
	}

	func requestPermissionForNotifications()
	{
		self.userCenter.requestAuthorization(options: self.userNotifyOptions) { (granted, _) in
			self.updateEnabledStatus()
		}
	}

	fileprivate func notifySave(_ sampleUrl: URL)
	{
		guard self.isEnabled else {
			print("Cannot send notification")
			return
		}

		cancelAll {
			let content = UNMutableNotificationContent()
			content.userInfo = [Config.sampleUrlKey: sampleUrl.absoluteString]
			content.title = NSString.localizedUserNotificationString(forKey: "Save TuneURL?", arguments: nil)
			content.body = NSString.localizedUserNotificationString(forKey: "If yes, tap", arguments: nil)
			content.categoryIdentifier = Config.saveCategory
			let request = UNNotificationRequest(identifier: UUID.init().uuidString, content: content, trigger: nil)

			self.userCenter.add(request) { (error) in
				print(error?.localizedDescription ?? "no error")
			}
		}
	}

	fileprivate func cancelAll(completion: @escaping ()->())
	{
		self.userCenter.getDeliveredNotifications { (notifications) in
			notifications.forEach({ (notification) in
				let content = notification.request.content
				guard content.categoryIdentifier == Config.saveCategory,
					let sampleUrlString = content.userInfo[Config.sampleUrlKey] as? String,
					let sampleUrl = URL(string: sampleUrlString) else {
						return
				}

				try? FileManager.default.removeItem(at: sampleUrl)
			})

			self.userCenter.removeAllDeliveredNotifications()
			completion()
		}
	}

}

extension Notify: UNUserNotificationCenterDelegate {

	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
	{
		let content = response.notification.request.content
		let notificationId = response.notification.request.identifier
		guard content.categoryIdentifier == Config.saveCategory,
			let sampleUrlString = content.userInfo[Config.sampleUrlKey] as? String,
			let sampleUrl = URL(string: sampleUrlString) else {
				return
		}

		self.delegate?.notificationSelected(sampleUrl: sampleUrl, notificationId: notificationId)
		completionHandler()
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
	{

//        let content = notification.request.content
//        let notificationId = notification.request.identifier
//        guard content.categoryIdentifier == Config.saveCategory,
//            let sampleUrlString = content.userInfo[Config.sampleUrlKey] as? String,
//            let sampleUrl = URL(string: sampleUrlString) else {
//
//                return
//        }
//
//        let alert = UIAlertController(title: "Save TuneURL?",
//                                      message: "",
//                                      preferredStyle: .alert)
//        let actionYes = UIAlertAction(title: "Yes", style: .default) { _ in
//            self.delegate?.notificationSelected(sampleUrl: sampleUrl,
//                                                notificationId: notificationId)
//        }
//        let actionNo = UIAlertAction(title: "No", style: .default, handler: nil)
//        alert.addAction(actionYes)
//        alert.addAction(actionNo)
//
//        UIApplication.shared.keyWindow?.rootViewController?.present(alert,
//                                                                    animated: true,
//                                                                    completion: nil)

		completionHandler(.alert)
	}

}

extension Notify: AudioMatcherDelegate {

	func sampleReady(_ sampleUrl: URL)
	{
		SamplesManager.shared.sample(for: sampleUrl) { _ in
			self.notifySave(sampleUrl)
		}
	}

}
