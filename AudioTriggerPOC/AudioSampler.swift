//
//  AudioSampler.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-18.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioSamplerDelegate {
//    func sampleReady(_ sample: Data)
    func sampleReady(_ sampleUrl: URL)
}

class AudioSampler: NSObject {
    private let duration = TimeInterval(5)
    fileprivate var recorder: AVAudioRecorder!
    fileprivate let audioSession = AVAudioSession.sharedInstance()
    fileprivate var isRunning: Bool
    var delegate: AudioSamplerDelegate?

    override init() {
        self.isRunning = false
        super.init()
    }

    func requestAccess() {
        let session = self.audioSession

        session.requestRecordPermission { granted in
            if granted {
                print("Permission to record granted")
            } else {
                print("Permission to record NOT granted")
            }
        }

        if session.recordPermission == .denied {
            print("audio permission denied")
        }
    }

    fileprivate func recordWithPermission(_ setup: Bool) {
        let session = self.audioSession

        session.requestRecordPermission {
            [unowned self] granted in
            if granted {
                DispatchQueue.main.async {
                    self.setSessionRecord()
                    if setup {
                        self.setupRecorder()
                    }
                    print("recording for \(self.duration) sesc")
                    self.recorder.record(forDuration: self.duration)
                }
            } else {
                print("Permission to record not granted")
            }
        }

        if session.recordPermission == .denied {
            print("permission denied")
        }
    }

    fileprivate func setSessionRecord() {
        let session = self.audioSession
        do {
            try session.setCategory(AVAudioSession.Category.record, mode: .default)
//            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            print("could not set session category with error: \n" + error.localizedDescription)
        }

        do {
            try session.setActive(true)
        } catch {
            print("could not make session active")
            print(error.localizedDescription)
        }
    }

    fileprivate func setupRecorder() {
        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
        let currentFileName = "recording-\(format.string(from: Date())).m4a"
//        let currentFileName = "recording.m4a"
        print(currentFileName)

        let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first!
        let soundFileURL = documentsDirectory.appendingPathComponent(currentFileName)
        print("writing to soundfile url: '\(soundFileURL)'")

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
            print("Unable to record")
            print(error.localizedDescription)
        }

    }

    fileprivate func record() {
        if recorder == nil {
            print("recording. recorder nil")
            recordWithPermission(true)
        } else {
            print("recording. recorder NOT nil")
            self.recorder.record(forDuration: duration)
            recordWithPermission(false)
        }
    }
}

// MARK: AVAudioRecorderDelegate
extension AudioSampler: AVAudioRecorderDelegate {

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                         successfully flag: Bool) {

        done(recorder, success: true)
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder,
                                          error: Error?) {
        done(recorder, success: false)

        if let e = error {
            print("audio encode error: \n" + e.localizedDescription)
        }
    }

    func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        done(recorder, success: false)
    }

    func audioRecorderEndInterruption(_ recorder: AVAudioRecorder, withOptions flags: Int) {
        //TODO:
    }

    func done(_ recorder: AVAudioRecorder, success: Bool) {
        defer {
            self.recorder = nil
            self.isRunning = false
        }

        guard success else {
            print("Finished recording with error")
            return
        }

//        guard let sample = try? NSData(contentsOf: recorder.url) as Data else {
//            print("Finished recording with no data")
//            return
//        }

//        try? FileManager.default.removeItem(at: recorder.url)
        self.delegate?.sampleReady(recorder.url)
    }

}

// MARK: AudioMatcherDelegate
extension AudioSampler: AudioMatcherDelegate {
    func foundMatch(_ matcher: AudioMatcher) {
        record()
    }
}
