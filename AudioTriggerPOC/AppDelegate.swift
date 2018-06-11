//
//  AppDelegate.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit
import RunACRSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    enum RunAcrConfig {
        fileprivate static let `default` = RunACR.sharedInstance()!
        fileprivate static let apiKey = "23541eb601555bd15ee658741aa070b2"
        fileprivate static let matchDataPath = Bundle.main.path(forResource: "combined",
                                                                ofType: "runacr")!
        fileprivate static let matcher = AudioMatcher(runAcr: RunAcrConfig.default,
                                                      apiKey: RunAcrConfig.apiKey,
                                                      sampleDataPath: RunAcrConfig.matchDataPath)
        fileprivate static let sampler = AudioSampler()
        fileprivate static let notify = Notify()
    }


    var window: UIWindow?
    fileprivate var bgTask = UIBackgroundTaskInvalid

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        firstStart(application)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        enterBackground(application)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        enterForeground(application)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        becomeActive(application)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

extension AppDelegate {
    fileprivate func stopBackgroundTask(_ application: UIApplication) {
        if bgTask != UIBackgroundTaskInvalid {
            application.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        }
    }

    fileprivate func firstStart(_ application: UIApplication) {
        RunAcrConfig.matcher.delegate = RunAcrConfig.sampler
        DispatchQueue.main.async {
            self.enterForeground(application)
        }
    }

    fileprivate func enterBackground(_ application: UIApplication) {
        bgTask = application.beginBackgroundTask {
            print("bg task ended")
            self.stopBackgroundTask(application)
        }
    }

    fileprivate func enterForeground(_ application: UIApplication) {
        stopBackgroundTask(application)

//        let jsonString = "{\"song_id\":56,\"description\":\"Nice Song Described here -- testfile2+opening audio\",\"title\":\"Nice Song - testfile2+opening audio\",\"url\":\"http://www.google.com/songs/testfile2+opening audio.mp3\",\"song_name\":\"testfile2+opening audio\",\"file_sha1\":\"128837DEB9A2E6C458630E37B22547E147228578\",\"confidence\":38,\"offset_seconds\":-0.04644,\"match_time\":2.53413987159729,\"offset\":-1}"
//        let jsonData = jsonString.data(using: .utf8)!
//        let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments)
//        let dummyData = SampleData(jsonDict: jsonDict as! [String: Any])!
//
//        self.sampleDataManager.add(dummyData)
    }

    fileprivate func becomeActive(_ application: UIApplication) {
        RunAcrConfig.notify.requestAccess()
        RunAcrConfig.sampler.requestAccess()
        RunAcrConfig.sampler.delegate = RunAcrConfig.notify
        RunAcrConfig.matcher.start()
        RunAcrConfig.notify.delegate = self
    }
}

extension AppDelegate: NotifyDelegate {
    func notificationSelected(sampleUrl: URL, notificationId: String) {
        let swipeActionViewController = SwipeActionViewController.create(with: sampleUrl)
        self.window?.rootViewController?.present(swipeActionViewController,
                                                 animated: true,
                                                 completion: nil)
    }
}
