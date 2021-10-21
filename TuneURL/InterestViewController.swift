//
//  InterestViewController.swift
//  TuneURL
//
//  Created by brandon bohach on 12/9/20.
//  Copyright © 2020-2021 TuneURL Inc. All rights reserved.
//


import DMSwipeCards
import Speech
import TuneURL
import UIKit


class InterestViewController: UIViewController, DMSwipeCardsViewDelegate {

    // private
    private var matchedItem: MatchedItem?
    //private let pollManager = PollManager()
    private let reportingManager = ReportingManager()
    private var swipeView: DMSwipeCardsView<String>!
    private var voted = false

    private let greenYes = UIColor(red: (35.0 / 255.0), green: (188.0 / 255.0), blue: (73.0 / 255.0), alpha: 1.0)
    private let redNo = UIColor(red: (240.0 / 255.0), green: (83.0 / 255.0), blue: (73.0 / 255.0), alpha: 1.0)

    // speech recognition
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var useSpeechRecognition = false

    // MARK: -

    class func create(with item: MatchedItem, wasUserInitiated: Bool) -> InterestViewController
    {
        let viewController = InterestViewController(nibName: nil, bundle: nil)
        viewController.matchedItem = item
        //viewController.useSpeechRecognition = (wasUserInitiated == false)
        return viewController
    }

    // MARK: - UIViewController

    override func viewDidLoad()
    {
        super.viewDidLoad()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)

        //self.view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)

        let viewGenerator: (String, CGRect) -> (UIView) = {
            (element: String, frame: CGRect) -> (UIView) in

            let container = UIView(frame: CGRect(x: 0, y: 0, width: (frame.width), height: (frame.height)))
            container.backgroundColor = UIColor(red: 0.11, green: 0.48, blue: 0.53, alpha: 1.00)
            container.layer.cornerRadius = 20
            container.clipsToBounds = true

            let touchViewWidth: CGFloat = container.frame.width/2
            let touchViewHeight: CGFloat = touchViewWidth

            let leftView = UIView(frame: CGRect(x: (-touchViewWidth / 4.0), y: (container.frame.height / 2.0 - touchViewHeight / 2.0), width: touchViewWidth, height: touchViewHeight))
            leftView.backgroundColor = self.greenYes
            leftView.layer.cornerRadius = touchViewWidth/2
            container.addSubview(leftView)
            let leftLabelRect = CGRect(x: leftView.bounds.origin.x + touchViewWidth / 4.0, y: leftView.bounds.origin.y, width: leftView.bounds.width * 3.0 / 4.0, height: leftView.bounds.height)
            addLabel(in: leftView, text: "YES >", with: leftLabelRect)

            let rightView = UIView(frame: CGRect(x: container.frame.width - touchViewWidth + touchViewWidth / 4.0, y: container.frame.height / 2.0 - touchViewHeight / 2.0, width: touchViewWidth, height: touchViewHeight))
            rightView.backgroundColor = self.redNo
            rightView.layer.cornerRadius = touchViewWidth/2
            container.addSubview(rightView)
            let rightLabelRect = CGRect(x: rightView.bounds.origin.x, y: rightView.bounds.origin.y, width: rightView.bounds.width * 3.0 / 4.0, height: rightView.bounds.height)
            addLabel(in: rightView, text: "< NO", with: rightLabelRect)

            let labelHeight = CGFloat(100.0)
            let label = UILabel(frame: CGRect(x: container.bounds.origin.x, y: container.bounds.height - labelHeight, width: container.bounds.width, height: labelHeight))
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

        func addLabel(in container: UIView, text: String, with rect: CGRect? = nil)
        {
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

        let overlayGenerator: (SwipeMode, CGRect) -> (UIView) = {
            (mode: SwipeMode, frame: CGRect) -> (UIView) in

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

        let frame = CGRect(x: 0.0, y: 80.0, width: self.view.frame.width, height: self.view.frame.height - 160.0)
        swipeView = DMSwipeCardsView<String>(frame: frame, viewGenerator: viewGenerator, overlayGenerator: overlayGenerator)
        swipeView.delegate = self
        self.view.addSubview(swipeView)

        addCard()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)

        if (useSpeechRecognition) {
            // request speech recognition permission
            if (SFSpeechRecognizer.authorizationStatus() == .authorized) {
                // start speech recognition
                DispatchQueue.main.async {
                    _ = try? self.startSpeechRecognition()
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        // stop speech recognition
        stopSpeechRecognition()

        super.viewWillDisappear(animated)
    }

    @objc func applicationWillResignActive()
    {
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
        self.dismiss(animated: false, completion: nil)
    }

    // MARK: - Private

    private func addCard()
    {
        self.swipeView.addCards(["Interested? Swipe left or right"], onTop: true)
    }

    private func addDoneView()
    {
//        let doneView = UIView(frame: self.view.frame)
//        doneView.backgroundColor = UIColor.white
//        self.view.addSubview(doneView)
//
//        let label = UILabel()
//        label.frame.size = CGSize(width: doneView.frame.width * 0.8, height: 100)
//        label.center = CGPoint(x: (doneView.frame.width / 2.0), y: (doneView.frame.height / 2.0))
//        label.clipsToBounds = true
//        label.font = UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.thin)
//        label.adjustsFontSizeToFitWidth = true
//        label.textAlignment = .center
//        label.numberOfLines = 0
//        label.textColor = UIColor.black
//        doneView.addSubview(label)
//
//        label.text = "Your choice has been recorded\nThank you"
    }

    // MARK: - Speech recognition

    private func speechRecognized(_ text: String)
    {
        // safety check
        guard voted == false else {
            return
        }

        // search the text for the speech commands
        let searchText = text.lowercased()
        if searchText.contains("yes") {
            // count a 'yes' vote
            DispatchQueue.main.async {
                self.swipedRight(self)
                self.dismiss(animated: true, completion: nil)
            }
            voted = true
        } else if searchText.contains("no") {
            // count a 'no' vote
            DispatchQueue.main.async {
                self.swipedLeft(self)
                self.dismiss(animated: true, completion: nil)
            }
            voted = true
        }
    }

    private func startSpeechRecognition() throws
    {
        // safety check
        guard (speechRecognizer == nil), (recognitionTask == nil) else {
            NSLog("InterestViewController: Error starting speech recognition.")
            return
        }

        // setup the speech recognizer
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            NSLog("InterestViewController: Error creating speech recognizer.")
            return
        }
        self.speechRecognizer = speechRecognizer

        // setup the speech recognition request
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        self.recognitionRequest = recognitionRequest

        // keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        // setup the speech recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) {
            result, error in

            var isFinal = false

            if let result = result {
                // Update the text view with the results.
                isFinal = result.isFinal
                self.speechRecognized(result.bestTranscription.formattedString)
            }

            if (error != nil) || (isFinal == true) {
                // stop speech recognition on any error
                self.stopSpeechRecognition()
            }
        }

        // start receiving audio buffers
		TuneURL.Listener.audioBufferDelegate = { buffer in
			self.recognitionRequest?.append(buffer)
		}
    }

    private func stopSpeechRecognition()
    {
        // stop receiving audio buffers
		TuneURL.Listener.audioBufferDelegate = nil

        // stop speech recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        speechRecognizer = nil
    }

    // MARK: - DMSwipeCardsViewDelegate

    func swipedLeft(_ object: Any)
    {
        print("swiped left")
        // safety check
        guard (voted == false) else {
            return
        }

        // get the matched item
        guard let item = matchedItem else {
            NSLog("InterestViewController: Error with matched item on swipe.")
            return
        }

        // cast the vote
        //pollManager.castVote(userResponse: false, for: item)
        voted = true
        reportingManager.captureUserAction(for: item, interestAction: "acted")
        
        self.view.backgroundColor = UIColor(red: (240.0 / 255.0), green: (83.0 / 255.0), blue: (73.0 / 255.0), alpha: 0.5)
        // This is the end - close the pop-up
        //self.dismiss(animated: true, completion: nil)
    }

    func swipedRight(_ object: Any)
    {
        print("swiped right")
        // safety check
        guard (voted == false) else {
            return
        }

        // get the matched item
        guard let item = matchedItem else {
            NSLog("InterestViewController: Error with matched item on swipe.")
            return
        }

        // cast the vote
        //pollManager.castVote(userResponse: true, for: item)
        
        voted = true
        reportingManager.captureUserAction(for: item, interestAction: "acted")
        
        self.view.backgroundColor = UIColor(red: (35.0 / 255.0), green: (188.0 / 255.0), blue: (73.0 / 255.0), alpha: 0.5)

        handleItem(item)
        // Open up the item and continue the flow
    }

    func cardTapped(_ object: Any)
    {
    }

    func reachedEndOfStack()
    {
        //self.addDoneView()
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Private

    private func handleItem(_ item: MatchedItem, wasUserInitiated: Bool = false)
    {
        //reporting
        reportingManager.captureUserAction(for: item, interestAction: "interested")
        switch (item.action) {
            // Immediate action items - phone number, text message, open web page
            // Save items - coupons, save web page
            case .phoneNumber:
                // open the phone number
                if let phoneURL = item.phoneURL {
                    UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
                }
            case .openWebPage:
                // open web page
                if let itemURL = item.url {
                    UIApplication.shared.open(itemURL, options: [:], completionHandler: nil)
                }
            case .poll:
                // open the poll - this shouldn't happen here because polls are the only action that displays automatically, everything else is controlled with this interested pop-up
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.openPoll(with: item, wasUserInitiated: wasUserInitiated)
                }
            case .coupon, .saveWebPage:
                //print(item)
//                if let itemURL = item.url {
//                    UIApplication.shared.open(itemURL, options: [:], completionHandler: nil)
//                }
                print("Need to save these items - check if they're saving")
            default:
                break
        }
        
    }
}

