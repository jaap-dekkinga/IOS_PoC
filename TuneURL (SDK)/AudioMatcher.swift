//
//  AudioMatcher.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/12/19.
//  Copyright © 2019-2022 TuneURL Inc. All rights reserved.
//

import Foundation
import AVFoundation
@_implementationOnly import Fingerprint_Private

class AudioMatcher {

    // MARK: - Static props
	static let shared = AudioMatcher()

    // MARK: - Internal props
	var audioBufferDelegate: Listener.AudioBufferHandler?

	// MARK: - Internal (read-only) props
	internal private(set) var audioCapture: AudioCapture?
	internal private(set) var isRunning = false
	internal private(set) var triggerFingerprint: UnsafeMutablePointer<Fingerprint>?

	// MARK: - Private props
	private let audioBuffer: AudioBuffer
	private var matchHandler: Listener.MatchHandler?

	// MARK: - Init/deinit
	init() {
		// setup the audio buffer
		audioBuffer = AudioBuffer(captureDuration: 10.0, sampleRate: 44100.0)
		audioBuffer.reset()
	}

	deinit {
		FingerprintFree(triggerFingerprint)
		triggerFingerprint = nil
	}

	// MARK: - Public funcs
	func privateSetTrigger(from triggerFileURL: URL) {
		NSLog("privateSetTrigger called with %@",triggerFileURL.absoluteString)
	    FingerprintFree(triggerFingerprint)
	    triggerFingerprint = nil
	    
	    // create the fingerprint
	    if let fingerprint = AudioUtility.generateFingerprint(for: triggerFileURL) {
	        triggerFingerprint = fingerprint
	        
	        #if DEBUG
	        if let data = fingerprint.pointee.data {
	            let size = Int(fingerprint.pointee.dataSize)
	            let bytes = (0..<size).map { data[$0] }
	            let versionLabel = bytes.first == UInt8(FINGERPRINT_MAGIC) ? "V2" : "V1"
	            let hexPreview = bytes.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
	            print("TuneURL: OTA trigger fingerprint loaded (\(versionLabel), \(size) bytes)")
	            print("TuneURL: OTA trigger first bytes: \(hexPreview)...")
	            print("TuneURL: OTA trigger full bytes: \(bytes)")
	        }
	        #endif
	    }
	}

	func start(matchHandler: @escaping Listener.MatchHandler) {
        #if DEBUG
        Debug.prepareRecordingsFolder()
        #endif // DEBUG
		// save the match handler
		self.matchHandler = matchHandler

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
					NSLog("TuneURL: Does not have recording permission.")
				}
			}
		}
	}

	func stop() {
		// stop audio capture
		audioCapture?.stop()
		audioCapture = nil

		// cleanup
		matchHandler = nil
		isRunning = false
	}

	// MARK: - Recognition
	func recognizedTrigger(timeRelativeToNow: Float) {
		let formatter = DateFormatter()
		formatter.dateStyle = .none
		formatter.timeStyle = .medium
		let currentTime = formatter.string(from: Date())

#if DEBUG
		print("TuneURL: (\(currentTime)): Did Recognize: window time: \(-timeRelativeToNow) seconds ago")
#endif // DEBUG

		// calculate how much of the sample has already been recorded
		let triggerSoundDuration = 2.0
		// Note: adding a half second of audio to the identifiable audio section to accomodate
		// processing time.
		let identifiableAudioDuration = 5.0
		let recordedSampleDuration = (Double(timeRelativeToNow) - triggerSoundDuration)
		var remainingTimeToRecord = (identifiableAudioDuration - recordedSampleDuration)
		remainingTimeToRecord = max(remainingTimeToRecord, 0.0)

		DispatchQueue.main.asyncAfter(deadline: (.now() + remainingTimeToRecord)) {

			// create the tuneurl fingerprint
			guard let matchAudioBuffer = self.audioBuffer.copyBufferData(maxDuration: identifiableAudioDuration),
			      let matchResampledBuffer = AudioUtility.changeSampleRate(sampleRate: FINGERPRINT_SAMPLE_RATE, buffer1: matchAudioBuffer),
			      let matchFingerprint = ExtractFingerprint(matchResampledBuffer, Int32(matchResampledBuffer.count), Int32(FORMAT_VERSION_V2)) else {
				return
			}

#if DEBUG
			print("matchAudioBuffer size: \(matchAudioBuffer.count)")
			print("matchResampledBuffer size: \(matchResampledBuffer.count)")
			print("matchFingerprint size: \(matchFingerprint.pointee.dataSize)")
			let tempPointer = matchFingerprint.pointee.data!
			var tempString = "["
			for tempValueIndex in 0 ..< Int(matchFingerprint.pointee.dataSize) {
				tempString += "\(tempPointer[tempValueIndex])"
				if (tempValueIndex < (matchFingerprint.pointee.dataSize - 1)) {
					tempString += ","
				} else {
					tempString += "]"
				}
			}
			print(tempString)

			// create the file name
			let recordingFolderURL = Debug.recordingFolderURL
			let format = DateFormatter()
			format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
			let filename = "Match-\(format.string(from: Date()))"

			// write the fingerprint
			let resultsFileURL = recordingFolderURL.appendingPathComponent(filename + ".txt")
			_ = try? tempString.write(to: resultsFileURL, atomically: true, encoding: .utf8)

			// write the tuneurl audio
			let fingerprintFileURL = recordingFolderURL.appendingPathComponent(filename + ".aif")
			_ = try? AudioUtility.writeAudioFile(to: fingerprintFileURL, buffer: matchAudioBuffer, sampleRate: 44100.0)
            
            print("TuneURL: Match audio written to: \(fingerprintFileURL)")
#endif // DEBUG

			// create the match fingerprint data
			var matchFingerprintData = [UInt8]()
			let pointer = matchFingerprint.pointee.data!
			for x in 0 ..< Int(matchFingerprint.pointee.dataSize) {
				matchFingerprintData.append(pointer[x])
			}

			// cleanup
			FingerprintFree(matchFingerprint)

		// ask the server to match the audio (V2 primary, V1 fallback)
			Server.shared.matchFingerprint(for: matchFingerprintData, queue: nil) { (match: Match?) in
				if let match = match {
					match.fingerprintVersion = "V2"
					if let handler = self.matchHandler {
						handler(match)
					}
					return
				}

				// V2 returned no match — fall back to V1 once
#if DEBUG
				print("TuneURL: V2 match returned nil, retrying with V1 fingerprint.")
#endif

				guard let v1Fingerprint = ExtractFingerprint(
					matchResampledBuffer,
					Int32(matchResampledBuffer.count),
					Int32(FORMAT_VERSION_V1)
				) else {
					return
				}

				var v1Data = [UInt8]()
				let v1Pointer = v1Fingerprint.pointee.data!
				for x in 0 ..< Int(v1Fingerprint.pointee.dataSize) {
					v1Data.append(v1Pointer[x])
				}
				FingerprintFree(v1Fingerprint)

				Server.shared.matchFingerprint(for: v1Data, queue: nil) { (fallbackMatch: Match?) in
					if let fallbackMatch = fallbackMatch, let handler = self.matchHandler {
						fallbackMatch.fingerprintVersion = "V1"
						handler(fallbackMatch)
					}
				}
			}
		}
	}

	// MARK: - Private funcs
	private func startMatching() {
		DispatchQueue.main.async {
			// start audio capture
			if (self.audioCapture == nil) {
				self.audioBuffer.reset()
				self.audioCapture = AudioCapture(audioBuffer: self.audioBuffer, sampleRate: 44100.0, delegate: nil)
				_ = self.audioCapture?.start()
			}
		}

		isRunning = true
	}
}
