//
//  SwipeActionViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-06-09.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

class SwipeActionViewController: UIViewController {
    @IBOutlet weak var swipeGestureRecognizer: UISwipeGestureRecognizer!

    fileprivate var hasUserResponse = false
    fileprivate var sampleUrl: URL?
    fileprivate let voteManager = VoteManager()
}

extension SwipeActionViewController {
    class func create(with sampleUrl: URL) -> SwipeActionViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SwipeActionViewController-SI")
            as! SwipeActionViewController
        vc.sampleUrl = sampleUrl
        return vc
    }
}

extension SwipeActionViewController {
    @IBAction func didSwipe(gestureRecognizer: UISwipeGestureRecognizer) {
        guard !hasUserResponse else {
            return
        }

        var userResponse: Bool? = nil
        switch gestureRecognizer.direction {
        case UISwipeGestureRecognizer.Direction.left:
            userResponse = false
        case UISwipeGestureRecognizer.Direction.right:
            userResponse = true
        default:
            print("none")
        }

        if let response = userResponse, let url = sampleUrl {
            hasUserResponse = true
            voteManager.castVote(userResponse: response, for: url)
        }
        self.dismiss(animated: true, completion: nil)
    }
}
