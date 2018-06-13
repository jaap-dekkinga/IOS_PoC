//
//  SwipeCardActionViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-06-13.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit
import DMSwipeCards

class SwipeCardActionViewController: UIViewController {
    private var swipeView: DMSwipeCardsView<String>!
    private var count = 0

    fileprivate var sampleUrl: URL?
    fileprivate let voteManager = VoteManager()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)

        /*
         * In this example we're using `String` as a type.
         * You can use DMSwipeCardsView though with any custom class.
         */

        let viewGenerator: (String, CGRect) -> (UIView) = { (element: String, frame: CGRect) -> (UIView) in
            let container = UIView(frame: CGRect(x: 30, y: 20, width: frame.width - 60, height: frame.height - 40))
//            let label = UILabel(frame: container.bounds)
//            label.text = element
//            label.textAlignment = .center
//            label.backgroundColor = UIColor.white
//            label.font = UIFont.systemFont(ofSize: 48, weight: UIFont.Weight.thin)
//            label.clipsToBounds = true
//            label.layer.cornerRadius = 16
//            container.addSubview(label)

            let imageView = UIImageView(frame: container.bounds)
            imageView.image = #imageLiteral(resourceName: "swipeScreen")
            container.addSubview(imageView)

            container.layer.shadowRadius = 4
            container.layer.shadowOpacity = 1.0
            container.layer.shadowColor = UIColor(white: 0.9, alpha: 1.0).cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 0)
            container.layer.shouldRasterize = true
            container.layer.rasterizationScale = UIScreen.main.scale

            return container
        }

        let overlayGenerator: (SwipeMode, CGRect) -> (UIView) = { (mode: SwipeMode, frame: CGRect) -> (UIView) in
            let label = UILabel()
            label.frame.size = CGSize(width: 100, height: 100)
            label.center = CGPoint(x: frame.width / 2, y: frame.height / 2)
            label.layer.cornerRadius = label.frame.width / 2
            label.backgroundColor = mode == .left ? UIColor.red : UIColor.green
            label.clipsToBounds = true
            label.text = mode == .left ? "👎" : "👍"
            label.font = UIFont.systemFont(ofSize: 24)
            label.textAlignment = .center
            return label
        }

        let frame = CGRect(x: 0, y: 80, width: self.view.frame.width, height: self.view.frame.height - 160)
        swipeView = DMSwipeCardsView<String>(frame: frame,
                                             viewGenerator: viewGenerator,
                                             overlayGenerator: overlayGenerator)
        swipeView.delegate = self
        self.view.addSubview(swipeView)

        addCard()
    }

    func addCard() {
        self.swipeView.addCards(["The One"], onTop: true)
        self.count = self.count + 1
    }
}

extension SwipeCardActionViewController: DMSwipeCardsViewDelegate {
    func swipedLeft(_ object: Any) {
        guard let url = sampleUrl else {
            print("Error on swipe left, no url")
            return
        }
        voteManager.castVote(userResponse: false, for: url)
    }

    func swipedRight(_ object: Any) {
        guard let url = sampleUrl else {
            print("Error on swipe right, no url")
            return
        }
        voteManager.castVote(userResponse: true, for: url)
    }

    func cardTapped(_ object: Any) {
        print("Tapped on: \(object)")
    }

    func reachedEndOfStack() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SwipeCardActionViewController {
    class func create(with sampleUrl: URL) -> SwipeCardActionViewController {
        let vc = SwipeCardActionViewController(nibName: nil, bundle: nil)
        vc.sampleUrl = sampleUrl
        return vc
    }
}
