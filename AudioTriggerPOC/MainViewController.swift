//
//  MainViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit
import RunACRSDK
import AVFoundation

class MainViewController: UIViewController {
    @IBOutlet weak var outputTextView: UITextView!

    let runAcr = RunACR.sharedInstance()!
    let audioMatchDataPath = Bundle.main.path(forResource: "combined", ofType: "runacr")
    var recorder: AVAudioRecorder!
    let audioSession = AVAudioSession.sharedInstance()
    var soundFileURL: URL!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.runAcr.initialize(withAPIKey: "23541eb601555bd15ee658741aa070b2")
        self.runAcr.delegate = self
        self.runAcr.updateDatabasePath(self.audioMatchDataPath)

        self.outputTextView.text = "ALL PROCESS OUTPUT:"

        DispatchQueue.main.async {
            self.runAcr.startRecognize()
            self.logToOutput("startRecognize")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension MainViewController: RunACRDelegate {
    func didRecognize(_ trackId: Int32, absoluteTimeOffset: Float, relativeTimeOffset: Float) {
        self.logToOutput("did Recognize")
        self.record()
    }

    func didNotRecognize() {
        self.logToOutput("did Not Recognize")
        self.runAcr.startRecognize()
    }
}

extension MainViewController {
    fileprivate func recordWithPermission(_ setup: Bool) {
        self.logToOutput("\(#function)")
        let session = self.audioSession

        session.requestRecordPermission {
            [unowned self] granted in
            if granted {

                DispatchQueue.main.async {
                    self.logToOutput("Permission to record granted")
                    self.setSessionRecord()
                    if setup {
                        self.setupRecorder()
                    }
                    self.logToOutput("recording for 10 sesc")
                    self.recorder.record(forDuration: TimeInterval(10))
                }
            } else {
                self.logToOutput("Permission to record not granted")
            }
        }

        if session.recordPermission() == .denied {
            self.logToOutput("permission denied")
        }
    }

    fileprivate func setSessionRecord() {
//    fileprivate func setSessionPlayAndRecord() {
        self.logToOutput("\(#function)")

        let session = self.audioSession
        do {
            try session.setCategory(AVAudioSessionCategoryRecord)
//            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            self.logToOutput("could not set session category")
            print(error.localizedDescription)
        }

        do {
            try session.setActive(true)
        } catch {
            self.logToOutput("could not make session active")
            print(error.localizedDescription)
        }
    }

    fileprivate func setupRecorder() {
        self.logToOutput("\(#function)")

        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
//        let currentFileName = "recording-\(format.string(from: Date())).m4a"
        let currentFileName = "recording.m4a"
        print(currentFileName)

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.soundFileURL = documentsDirectory.appendingPathComponent(currentFileName)
        print("writing to soundfile url: '\(soundFileURL!)'")
        self.logToOutput("writing to soundfile url: '\(currentFileName)'")

        if FileManager.default.fileExists(atPath: soundFileURL.absoluteString) {
            // probably won't happen. want to do something about it?
            print("soundfile \(soundFileURL.absoluteString) exists")
        }

        let recordSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey: 32000,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0
        ]


        do {
            recorder = try AVAudioRecorder(url: soundFileURL, settings: recordSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord() // creates/overwrites the file at soundFileURL
            self.logToOutput("Prepare to record")
        } catch {
            recorder = nil
            self.logToOutput("Unable to record")
            print(error.localizedDescription)
        }

    }

    fileprivate func record() {

        print("\(#function)")

        if recorder == nil {
            print("recording. recorder nil")
            recordWithPermission(true)
        } else {
            self.logToOutput("recording")
            self.recorder.record(forDuration: TimeInterval(10))
            recordWithPermission(false)
        }
    }
}

// MARK: AVAudioRecorderDelegate
extension MainViewController: AVAudioRecorderDelegate {

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                         successfully flag: Bool) {

        self.logToOutput("\(#function)")
        self.recorder = nil
        self.runAcr.startRecognize()
        self.sendEmail()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder,
                                          error: Error?) {
        self.logToOutput("\(#function)")

        if let e = error {
            print("\(e.localizedDescription)")
        }
    }

}

extension MainViewController {
    fileprivate func sendEmail() {
        guard let email = UserDefaults.standard.emailDestination else {
            self.logToOutput("Please set your email first!")
            return
        }
        let sendgrid = SendGrid(apiUser: "bi1zi1",
                                apiKey: "Test1234")
        let newEmail = SendGridEmail()
        newEmail.from = email
        newEmail.to = email
        newEmail.subject = "Audio recording"
        newEmail.text = "see attachment"
        if let attData = try? NSData(contentsOf: soundFileURL) as Data {
            let attachment = SendGridEmailAttachment()
            attachment.attachmentData = attData
            attachment.fileName = soundFileURL.lastPathComponent.split(separator: Character(".")).first?.lowercased()
            attachment.mimeType = "audio/x-m4a"
            attachment.extension = "m4a"
            newEmail.attachFile(attachment)
        }

//        sendgrid?.send(withWeb: newEmail)
//        sendgrid?.sendAttachment(withWeb: newEmail)
        sendgrid?.sendAttachment(withWeb: newEmail, successBlock: { (success) in
            self.logToOutput("Email sent")
        }, failureBlock: { (error) in
            self.logToOutput("Email not sent")
            print(error?.localizedDescription ?? "no error description")
        })
    }
}

extension MainViewController {
    fileprivate func logToOutput(_ text: String) {
        //Add newline
        self.outputTextView.text.append("\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let datePrefix = dateFormatter.string(from: Date())

        //Add "DATE: text"
        self.outputTextView.text.append(datePrefix)
        self.outputTextView.text.append(": ")
        self.outputTextView.text.append(text)
    }
}
