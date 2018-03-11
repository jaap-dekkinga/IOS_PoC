//
//  Notify.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-04.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UserNotifications

class Notify: NSObject {

    fileprivate enum Config {
        static let saveCategory = "saveCategory"
        static let saveCategoryActions: [UNNotificationAction] = []
    }

    fileprivate let userNotifyOptions: UNAuthorizationOptions = [.alert, .sound]
    fileprivate let userCenter = UNUserNotificationCenter.current()
    fileprivate(set) var isEnabled = false
    fileprivate let saveCategory = UNNotificationCategory(identifier: Config.saveCategory,
                                                          actions: [],
                                                          intentIdentifiers: [],
                                                          options: .customDismissAction)

    override init() {
        super.init()
        self.updateEnabledStatus()
        self.userCenter.setNotificationCategories([self.saveCategory])
        self.userCenter.delegate = self
    }

    private func updateEnabledStatus() {
        self.userCenter.getNotificationSettings { (settings) in
            self.isEnabled = settings.authorizationStatus == .authorized
                && settings.alertStyle != .none
        }
    }

    func requestAccess() {
        self.userCenter.requestAuthorization(options: self.userNotifyOptions) { (granted, _) in
            self.updateEnabledStatus()
        }
    }

    func notifySave() {
        guard self.isEnabled else {
            print("Cannot send notification")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "Save TuneURL?",
                                                                 arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "If yes, tap",
                                                                arguments: nil)
        content.categoryIdentifier = Config.saveCategory
        let request = UNNotificationRequest(identifier: UUID.init().uuidString,
                                            content: content,
                                            trigger: nil)

        self.userCenter.add(request) { (error) in
            print(error?.localizedDescription ?? "no error")
        }
    }

    func cancelAll() {
        self.userCenter.removeAllDeliveredNotifications()
    }
}

extension Notify: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        print(response)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        print(notification)
    }

}

