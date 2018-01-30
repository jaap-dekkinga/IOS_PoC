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
    let runAcr = RunACR.sharedInstance()!
    let audioMatchDataPath = Bundle.main.path(forResource: "combined", ofType: "runacr")
    var recorder: AVAudioRecorder!
    let audioSession = AVAudioSession.sharedInstance()
    var soundFileURL: URL!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.runAcr.initialize(withAPIKey: "23541eb601555bd15ee658741aa070b2")
        // Do any additional setup after loading the view, typically from a nib.
        self.runAcr.delegate = self
        self.runAcr.updateDatabasePath(self.audioMatchDataPath)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func start(_ sender: UIButton) {
        self.runAcr.startRecognize()
    }

}

extension MainViewController: RunACRDelegate {
    func didRecognize(_ trackId: Int32, absoluteTimeOffset: Float, relativeTimeOffset: Float) {
        self.record()
    }

    func didNotRecognize() {
        self.runAcr.startRecognize()
    }
}

extension MainViewController {
    fileprivate func recordWithPermission(_ setup: Bool) {
        print("\(#function)")
        let session = self.audioSession

        session.requestRecordPermission {
            [unowned self] granted in
            if granted {

                DispatchQueue.main.async {
                    print("Permission to record granted")
                    self.setSessionPlayAndRecord()
                    if setup {
                        self.setupRecorder()
                    }
                    self.recorder.record(forDuration: TimeInterval(10))
                }
            } else {
                print("Permission to record not granted")
            }
        }

        if session.recordPermission() == .denied {
            print("permission denied")
        }
    }

    fileprivate func setSessionPlayAndRecord() {
        print("\(#function)")

        let session = self.audioSession
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            print("could not set session category")
            print(error.localizedDescription)
        }

        do {
            try session.setActive(true)
        } catch {
            print("could not make session active")
            print(error.localizedDescription)
        }
    }

    fileprivate func setupRecorder() {
        print("\(#function)")

        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
//        let currentFileName = "recording-\(format.string(from: Date())).m4a"
        let currentFileName = "recording-same.m4a"
        print(currentFileName)

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.soundFileURL = documentsDirectory.appendingPathComponent(currentFileName)
        print("writing to soundfile url: '\(soundFileURL!)'")

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
        } catch {
            recorder = nil
            print(error.localizedDescription)
        }

    }

    fileprivate func record() {

        print("\(#function)")

        if recorder == nil {
            print("recording. recorder nil")
            recordWithPermission(true)
            return
        }

        if recorder != nil && recorder.isRecording {
            print("already recording")
//            print("pausing")
//            recorder.pause()

        } else {
            print("recording")
//            recorder.record()
            recordWithPermission(false)
        }
    }
}

// MARK: AVAudioRecorderDelegate
extension MainViewController: AVAudioRecorderDelegate {

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                         successfully flag: Bool) {

        print("\(#function)")
        self.recorder = nil
        self.runAcr.startRecognize()
        self.sendEmail()
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder,
                                          error: Error?) {
        print("\(#function)")

        if let e = error {
            print("\(e.localizedDescription)")
        }
    }

}

extension MainViewController {
    fileprivate func sendEmail() {
        let sendgrid = SendGrid(apiUser: "bi1zi1",
                                apiKey: "Test1234")
        let newEmail = SendGridEmail()
        newEmail.from = "a.mihailovski@gmail.com"
        newEmail.to = "a.mihailovski@gmail.com"
        newEmail.subject = "Bizi test"
        newEmail.text = "Bu"
        if let attData = try? NSData(contentsOf: soundFileURL) as Data {
            let attachment = SendGridEmailAttachment()
            attachment.attachmentData = attData
            attachment.fileName = soundFileURL.lastPathComponent
            attachment.mimeType = "audio/x-m4a"
            attachment.extension = "m4a"
            newEmail.attachFile(attachment)
        }

//        sendgrid?.send(withWeb: newEmail)
        sendgrid?.sendAttachment(withWeb: newEmail)
    }
}
