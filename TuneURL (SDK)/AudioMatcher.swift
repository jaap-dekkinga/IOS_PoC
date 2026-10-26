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
	/// Trigger length in samples at the fingerprint sample rate (for the sliding search).
	internal private(set) var triggerSampleCount = 0
	/// Microphone check references: high-passed trigger plus echoey copies
	/// (see AudioUtility.makeTriggerReferences). Same length as the trigger.
	internal private(set) var triggerReferences: [UnsafeMutablePointer<Fingerprint>] = []
	internal private(set) var triggerReferenceLabels: [String] = []
	/// Held while the trigger fingerprints are replaced or used. Trigger
	/// checks run on a background queue, so this stops a new trigger from
	/// freeing fingerprints that a running check is still comparing with.
	private let triggerLock = NSLock()

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
		freeTriggerReferences()
	}

	// MARK: - Public funcs
	/// Runs `body` with the current trigger state, holding the trigger lock.
	func withTrigger<T>(_ body: (_ fingerprint: UnsafeMutablePointer<Fingerprint>?, _ sampleCount: Int,
	                             _ references: [UnsafeMutablePointer<Fingerprint>], _ labels: [String]) -> T) -> T {
		triggerLock.lock()
		defer { triggerLock.unlock() }
		return body(triggerFingerprint, triggerSampleCount, triggerReferences, triggerReferenceLabels)
	}

	func privateSetTrigger(from triggerFileURL: URL) {
		triggerLock.lock()
		defer { triggerLock.unlock() }
		NSLog("privateSetTrigger called with %@",triggerFileURL.absoluteString)
	    FingerprintFree(triggerFingerprint)
	    triggerFingerprint = nil
	    triggerSampleCount = 0
	    freeTriggerReferences()
	    
	    // create the fingerprint
	    if let trigger = AudioUtility.generateTriggerFingerprint(for: triggerFileURL) {
	        let fingerprint = trigger.fingerprint
	        triggerFingerprint = fingerprint
	        triggerSampleCount = trigger.sampleCount
	        
	        // Unconditional version log — runs in any build config
	        if let data = fingerprint.pointee.data {
	            let firstByte = data[0]
	            let isV2 = (firstByte == UInt8(FINGERPRINT_MAGIC))
	            NSLog("TuneURL: TRIGGER VERSION = %@ (first byte 0x%02X, size %d)",
	                  isV2 ? "V2" : "V1",
	                  firstByte,
	                  fingerprint.pointee.dataSize)
	        } else {
	            NSLog("TuneURL: TRIGGER fingerprint has nil data pointer")
	        }
	    } else {
	        NSLog("TuneURL: TRIGGER generateFingerprint returned nil")
	    }

	    // references for the microphone check
	    if let samples = AudioUtility.loadTriggerSamples(for: triggerFileURL), samples.count == triggerSampleCount {
	        let references = AudioUtility.makeTriggerReferences(from: samples)
	        triggerReferences = references.map { $0.fingerprint }
	        triggerReferenceLabels = references.map { $0.label }
	    }
	    Diagnostics.log(String(format: "TuneURL_DIAG: ota trigger loaded: %ld samples, %ld references (%@), high-pass %.0f Hz",
	                           triggerSampleCount, triggerReferences.count,
	                           triggerReferenceLabels.joined(separator: ", "), AudioUtility.triggerHighPassCutoff))
	}

	private func freeTriggerReferences() {
	    for reference in triggerReferences {
	        FingerprintFree(reference)
	    }
	    triggerReferences = []
	    triggerReferenceLabels = []
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

		Diagnostics.log(String(format: "TuneURL_DIAG: ota trigger recognised (started %.2f s ago); sending 5 s of audio to the server in %.1f s",
		                       timeRelativeToNow, remainingTimeToRecord))

		DispatchQueue.main.asyncAfter(deadline: (.now() + remainingTimeToRecord)) {

			// create the tuneurl fingerprint
			guard let matchAudioBuffer = self.audioBuffer.copyBufferData(maxDuration: identifiableAudioDuration),
			      let matchResampledBuffer = AudioUtility.changeSampleRate(sampleRate: FINGERPRINT_SAMPLE_RATE, buffer1: matchAudioBuffer),
			      let matchFingerprint = ExtractFingerprint(matchResampledBuffer, Int32(matchResampledBuffer.count), Int32(FORMAT_VERSION_V2)) else {
				Diagnostics.log("TuneURL_DIAG: ota server: not sent (could not prepare the audio)")
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

			// cleanup (the V2 fingerprint is only used for the DEBUG dump above)
			FingerprintFree(matchFingerprint)

			// ask the server to match the audio with the V1 fingerprint only,
			// same as StreamDetector
			guard let v1Fingerprint = ExtractFingerprint(
				matchResampledBuffer,
				Int32(matchResampledBuffer.count),
				Int32(FORMAT_VERSION_V1)
			) else {
				Diagnostics.log("TuneURL_DIAG: ota server: not sent (could not make the V1 fingerprint)")
				return
			}

			var v1Data = [UInt8]()
			let v1Pointer = v1Fingerprint.pointee.data!
			for x in 0 ..< Int(v1Fingerprint.pointee.dataSize) {
				v1Data.append(v1Pointer[x])
			}
			FingerprintFree(v1Fingerprint)

			Server.shared.matchFingerprint(for: v1Data, queue: nil) { (match: Match?) in
				if let match = match {
					Diagnostics.log("TuneURL_DIAG: ota server: match id=\(match.id) matchPercentage=\(match.matchPercentage)% (app threshold applies next)")
				} else {
					Diagnostics.log("TuneURL_DIAG: ota server: no match (or request failed)")
				}
				if let match = match, let handler = self.matchHandler {
					match.fingerprintVersion = "V1"
					handler(match)
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
