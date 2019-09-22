//
//  AudioMatcher.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 3/18/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
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
	var triggerFingerprint = [UInt8]()

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
		prepareAudioTrigger()
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

	func recognizedSound(timeRelativeToNow: Float)
	{
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .medium
		let currentTime = formatter.string(from: Date())
		print("(\(currentTime)): Did Recognize: window time: \(-timeRelativeToNow) seconds ago")

		// verify matching is enabled
		if self.enabled == false {
			return
		}

		// calculate how much of the sample has already been recorded
		let triggerSoundDuration = 2.0
		// Note: adding a half second of audio to the identifiable audio section to accomodate
		// processing time.
		let identifiableAudioDuration = 5.0
		let recordedSampleDuration = (Double(timeRelativeToNow) - triggerSoundDuration)
		var remainingTimeToRecord = (identifiableAudioDuration - recordedSampleDuration)
		remainingTimeToRecord = max(remainingTimeToRecord, 0.0)

		DispatchQueue.main.asyncAfter(deadline: (.now() + remainingTimeToRecord)) {

			// create the recording file name
			let format = DateFormatter()
			format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
			let sampleFileName = "recording-\(format.string(from: Date())).m4a"

			// create the recording file url
			let recordingFolderURL = AppDelegate.recordingFolderURL
			let soundFileURL = recordingFolderURL.appendingPathComponent(sampleFileName)

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

	private func generateFingerprint(for fileURL: URL, resample: Bool) -> [UInt8]?
	{
		var result: OSStatus = noErr
		var audioFile: AudioFileID?
		var propertyDataSize: UInt32 = 8
		var dataSize: UInt64 = 0

		result = AudioFileOpenURL(fileURL as CFURL, .readPermission, kAudioFileAIFFType, &audioFile)
		if (result != noErr) {
			print("AudioMatcher: Error opening audio file. \(result)")
			return nil
		}

		result = AudioFileGetProperty(audioFile!, kAudioFilePropertyAudioDataByteCount, &propertyDataSize, &dataSize)
		if (result != noErr) {
			print("AudioMatcher: Error getting audio file property. \(result)")
			return nil
		}

		let frameCount = UInt32(dataSize >> 1)	// 16-bit audio
		var dataBuffer = [Int16](repeating: 0, count: Int(frameCount))
		dataBuffer.withUnsafeMutableBytes {
			bufferPointer in

			var packetCount = frameCount
			var dataRead = UInt32(dataSize)

			result = AudioFileReadPacketData(audioFile!, false, &dataRead, nil, 0, &packetCount, bufferPointer.baseAddress)
		}

		// check the result of the read
		if (result != noErr) {
			print("AudioMatcher: Error reading audio file packet data. \(result)")
			return nil
		}

		result = AudioFileClose(audioFile!)
		if (result != noErr) {
			print("AudioMatcher: Error closing audio file. \(result)")
		}

		let fingerprinter = FingerprintManager()
		if let fingerprint = fingerprinter.extractFingerprint(dataBuffer, resample: resample) {
			return fingerprint
		}

		return nil
	}

	private func prepareAudioTrigger()
	{
		// get the url for the trigger audio file
		guard let triggerFileURL = Bundle.main.url(forResource: "Trigger-Audio", withExtension: "wav") else {
			return
		}

		// create the fingerprint
		if let fingerprint = generateFingerprint(for: triggerFileURL, resample: true) {
			triggerFingerprint = fingerprint
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
