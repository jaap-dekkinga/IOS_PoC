//
//  AudioMatcher.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-18.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//


import AVFoundation
import Foundation


protocol AudioMatcherDelegate {
	func sampleReady(_ sampleUrl: URL)
}


class AudioMatcher: NSObject {

	// public
	var delegate: AudioMatcherDelegate?
	public private(set) var isRunning = false

	// private
	private let audioBuffer: AudioBuffer
	private var audioCapture: AudioCapture?

	// MARK: -

	var enabled: Bool = true {
		didSet {
			if enabled != oldValue {
				if enabled {
					start()
				} else {
					stop()
				}
			}
		}
	}

	// MARK: -

	override init()
	{
		// setup the audio buffer
		audioBuffer = AudioBuffer(captureDuration: 10.0, sampleRate: 44100.0)

		super.init()

		audioBuffer.reset()
	}

	func start()
	{
		let audioSession = AVAudioSession.sharedInstance()

		if (audioSession.recordPermission == .granted) {
			// start matching immediately
			startMatching()
		} else {
			// request microphone permission
			audioSession.requestRecordPermission {
				granted in
				if granted {
					// start matching
					self.startMatching()
				} else {
					print("AudioMatching: Does not have recording permission.")
				}
			}
		}
	}

	func stop()
	{
		// stop audio capture
		audioCapture?.stop()
		audioCapture = nil
	}

	// MARK: -

	func recognizedSound(_ trackId: Int32, absoluteTimeOffset: Float, relativeTimeOffset: Float)
	{
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .medium
		let currentTime = formatter.string(from: Date())
		print("(\(currentTime)): Did Recognize: window time: \(-absoluteTimeOffset) seconds, \(-relativeTimeOffset) seconds ago")

		// verify matching is enabled
		if self.enabled == false {
			return
		}

		// calculate how much of the sample has already been recorded
		let triggerSoundDuration = 2.0
		// Note: adding a half second of audio to the identifiable audio section to accomodate
		// processing time.
		let identifiableAudioDuration = 5.0
		let recordedSampleDuration = (Double(relativeTimeOffset) - triggerSoundDuration)
		var remainingTimeToRecord = (identifiableAudioDuration - recordedSampleDuration)
		remainingTimeToRecord = max(remainingTimeToRecord, 0.0)

		DispatchQueue.main.asyncAfter(deadline: (.now() + remainingTimeToRecord)) {

			// create the recording file name
			let format = DateFormatter()
			format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
			let sampleFileName = "recording-\(format.string(from: Date())).m4a"

			// create the recording file url
			let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
			let soundFileURL = documentsDirectory.appendingPathComponent(sampleFileName)

			print("writing to soundfile url: '\(soundFileURL)'")

			// write the sample to the file
			self.audioBuffer.export(to: soundFileURL, maxDuration: identifiableAudioDuration) {
				(Bool, Double) in
				// notify the delegate
				self.delegate?.sampleReady(soundFileURL)
			}
		}
	}

	// MARK: -
	// MARK: Private

	private func startMatching()
	{
		DispatchQueue.main.async {
			// start audio capture
			if (self.audioCapture == nil) {
				self.audioBuffer.reset()
				self.audioCapture = AudioCapture(audioBuffer: self.audioBuffer, sampleRate: 44100.0, delegate: nil)
				_ = self.audioCapture?.start()
			}
			// TODO: start audio matching...
		}
	}

}
