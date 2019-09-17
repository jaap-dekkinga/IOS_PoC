//
//  SwipeCardActionViewController.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 6/13/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import DMSwipeCards
import UIKit


class SwipeCardActionViewController: UIViewController {

	private var swipeView: DMSwipeCardsView<String>!
    private var count = 0
    fileprivate let notificationCenter = NotificationCenter.default

    fileprivate var sampleUrl: URL?
    fileprivate let voteManager = VoteManager()

    fileprivate let greenYes = UIColor(red: 35.0/255.0,
                                       green: 188.0/255.0,
                                       blue: 73.0/255.0,
                                       alpha: 1.0)
    fileprivate let redNo = UIColor(red: 240.0/255.0,
                                    green: 83.0/255.0,
                                    blue: 73.0/255.0,
                                    alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        notificationCenter.addObserver(self, selector: #selector(applicationWillResignActive),
                                       name: UIApplication.willResignActiveNotification,
                                       object: nil)

        self.view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)

        /*
         * In this example we're using `String` as a type.
         * You can use DMSwipeCardsView though with any custom class.
         */

        let viewGenerator: (String, CGRect) -> (UIView) = { (element: String, frame: CGRect) -> (UIView) in
            let container = UIView(frame: CGRect(x: 30, y: 20,
                                                 width: frame.width - 60,
                                                 height: frame.height - 40))
            container.backgroundColor = UIColor(red: 0.11,
                                                green: 0.48,
                                                blue: 0.53,
                                                alpha: 1.00)
            container.layer.cornerRadius = 20
            container.clipsToBounds = true

            let touchViewWidth: CGFloat = container.frame.width/2
            let touchViewHeight: CGFloat = touchViewWidth

            let leftView = UIView(frame: CGRect(x: -touchViewWidth/4,
                                                y: container.frame.height/2 - touchViewHeight/2,
                                                width: touchViewWidth,
                                                height: touchViewHeight))
            leftView.backgroundColor = self.greenYes
            leftView.layer.cornerRadius = touchViewWidth/2
            container.addSubview(leftView)
            let leftLabelRect = CGRect(x: leftView.bounds.origin.x + touchViewWidth/4,
                                       y: leftView.bounds.origin.y,
                                       width: leftView.bounds.width * 3/4,
                                       height: leftView.bounds.height)
            addLabel(in: leftView, text: "YES >", with: leftLabelRect)


            let rightView = UIView(frame: CGRect(x: container.frame.width - touchViewWidth + touchViewWidth/4,
                                                y: container.frame.height/2 - touchViewHeight/2,
                                                width: touchViewWidth,
                                                height: touchViewHeight))
            rightView.backgroundColor = self.redNo
            rightView.layer.cornerRadius = touchViewWidth/2
            container.addSubview(rightView)
            let rightLabelRect = CGRect(x: rightView.bounds.origin.x,
                                        y: rightView.bounds.origin.y,
                                        width: rightView.bounds.width * 3/4,
                                        height: rightView.bounds.height)
            addLabel(in: rightView, text: "< NO", with: rightLabelRect)

            let labelHeight = CGFloat(100)
            let label = UILabel(frame: CGRect(x: container.bounds.origin.x,
                                              y: container.bounds.height - labelHeight,
                                              width: container.bounds.width,
                                              height: labelHeight))
            label.text = element
            label.textAlignment = .center
            label.textColor = UIColor.white.withAlphaComponent(0.7)
            label.font = UIFont.systemFont(ofSize: 26, weight: UIFont.Weight.thin)
            label.clipsToBounds = true
            label.layer.cornerRadius = 16
            label.adjustsFontSizeToFitWidth = true
            container.addSubview(label)

            container.layer.shadowRadius = 4
            container.layer.shadowOpacity = 1.0
            container.layer.shadowColor = UIColor(white: 0.9, alpha: 1.0).cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 0)
            container.layer.shouldRasterize = true
            container.layer.rasterizationScale = UIScreen.main.scale

            return container
        }

        func addLabel(in container: UIView, text: String, with rect: CGRect? = nil) {
            let rect = rect ?? container.bounds
            let label = UILabel(frame: rect)
            label.text = text
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 32, weight: UIFont.Weight.thin)
            label.textColor = UIColor.white.withAlphaComponent(0.7)
            label.clipsToBounds = true
            label.adjustsFontSizeToFitWidth = true
            container.addSubview(label)
        }

        let overlayGenerator: (SwipeMode, CGRect) -> (UIView) = { (mode: SwipeMode, frame: CGRect) -> (UIView) in
            let label = UILabel()
            label.frame.size = CGSize(width: 100, height: 100)
            label.center = CGPoint(x: frame.width / 2, y: frame.height / 2)
            label.layer.cornerRadius = label.frame.width / 2
            label.backgroundColor = mode == .left ? self.redNo : self.greenYes
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

    private func addCard() {
        self.swipeView.addCards(["Swipe to make your choice"], onTop: true)
        self.count = self.count + 1
    }

    func addDoneView() {
        let doneView = UIView(frame: self.view.frame)
        doneView.backgroundColor = UIColor.white
        self.view.addSubview(doneView)

        let label = UILabel()
        label.frame.size = CGSize(width: doneView.frame.width * 0.8, height: 100)
        label.center = CGPoint(x: doneView.frame.width / 2,
                               y: doneView.frame.height / 2)
        label.clipsToBounds = true
        label.font = UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.thin)
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = UIColor.black
        doneView.addSubview(label)

        label.text = "Your choice has been recorded\nThank you"
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
        self.addDoneView()
    }
}

extension SwipeCardActionViewController {
    class func create(with sampleUrl: URL) -> SwipeCardActionViewController {
        let vc = SwipeCardActionViewController(nibName: nil, bundle: nil)
        vc.sampleUrl = sampleUrl
        return vc
    }

    @objc func applicationWillResignActive() {
        self.notificationCenter.removeObserver(self)
        self.dismiss(animated: false, completion: nil)
    }
}
