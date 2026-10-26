//
//  AudioCapture.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/2/19.
//  Copyright © 2019-2026 TuneURL Inc. All rights reserved.
//


import Foundation
import AVFoundation
@_implementationOnly import Fingerprint_Private

protocol AudioCaptureDelegate {
	func audioCaptureStatusChanged()
}

class AudioCapture: NSObject {

	// MARK: - Private props
	private let audioBuffer: AudioBuffer
	private var audioConverter: AVAudioConverter?
	private let audioEngine = AVAudioEngine()
	private let audioSession = AVAudioSession.sharedInstance()
	private let bufferFormat: AVAudioFormat
	private var delegate: AudioCaptureDelegate?
	private let sampleRate: Double
	private let triggerWindowDuration = 4.0
	private var useBufferConversion = false

	// Trigger search: the trigger is slid across the window in steps of
	// triggerSlideHop seconds (see AudioUtility.slideTrigger).
	private let triggerSlideHop = 0.125
	// Pass mark for the high-passed, multi-reference check that decides.
	// Scores come in steps of 0.04, so "> 0.18" accepts 0.20 and up. In room
	// simulations this kept music-only false passes at the old level (~5%)
	// while catching ~96% of triggers instead of ~74%.
	private let triggerThreshold: Float = 0.18
	// Pass mark of the previous check, which is still scored and logged for
	// comparison only.
	private let previousTriggerThreshold: Float = 0.1
	// With the sliding search one trigger is visible on 2-3 consecutive
	// checks; ignore further hits for this long after a detection.
	private let triggerCooldown: TimeInterval = 6.0
	// After a first hit, look again this much later and keep the better match:
	// the first hit often catches the trigger only partly inside the window,
	// which places its start imprecisely.
	private let triggerReLookDelay: TimeInterval = 1.0
	private var lastTriggerTime = Date.distantPast
	private var isConfirmingTrigger = false
	// Trigger checks run here, not on the main thread: each check now
	// fingerprints ~21 slices and compares each with 3 references.
	// lastTriggerTime and isConfirmingTrigger are only touched on this queue.
	private let detectionQueue = DispatchQueue(label: "com.TuneURL.AudioCapture.detection", qos: .userInitiated)

	// MARK: - Copmuted props
    var isRunning: Bool {
        return audioEngine.isRunning
    }
    
	// MARK: - Init/deinit
    init(
        audioBuffer buffer: AudioBuffer,
        sampleRate rate: Double,
        delegate: AudioCaptureDelegate?
    ) {
		// save the audio buffer
		audioBuffer = buffer
		sampleRate = rate
		self.delegate = delegate

		// setup the audio buffer format
		guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false) else {
			fatalError("Error creating audio buffer format.")
		}
		bufferFormat = format
	}

	deinit {
		// make sure recording has stopped
		stop()
	}

// MARK: - Public funcs
	func start() -> Bool {
		// safety check
		if self.isRunning {
			return true
		}

		// reset the audio buffer before recording
		audioBuffer.reset()

		// setup the audio session
		setupAudioSession()

		// start the audio engine
		if (startAudioEngine() == false) {
			return false
		}

		// setup the configuration change notification
		let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(audioEngineConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: audioEngine
        )

		return true
	}

	func stop() {
		// stop notifications
		NotificationCenter.default.removeObserver(self, name: nil, object: audioEngine)

		// stop the audio engine
		stopAudioEngine()

		// stop the audio session
		_ = try? audioSession.setActive(false)

		// notify the delegate
		delegate?.audioCaptureStatusChanged()
	}

	// MARK: - Private funcs
	/// One local search: how well the trigger matched and when it started.
	private struct TriggerLook {
		let similarity: Float
		let triggerStart: Date
		let passed: Bool
	}

	private func checkForTriggerSound() {
		audioBuffer.resetUntestedSize()

		// one trigger is visible on several consecutive checks
		if isConfirmingTrigger || Date().timeIntervalSince(lastTriggerTime) < triggerCooldown {
			return
		}

		guard let firstLook = searchForTrigger(label: ""), firstLook.passed else {
			return
		}

		lastTriggerTime = Date()
		isConfirmingTrigger = true

		// look once more when the trigger is fully in view, keep the better match
		detectionQueue.asyncAfter(deadline: .now() + triggerReLookDelay) {
			self.isConfirmingTrigger = false
			guard self.isRunning else { return }

			var hit = firstLook
			if let secondLook = self.searchForTrigger(label: " (re-look)"), secondLook.similarity > firstLook.similarity {
				hit = secondLook
			}

			let secondsAgo = Float(Date().timeIntervalSince(hit.triggerStart))
#if DEBUG
			print("TuneURL: Trigger detected \(secondsAgo) seconds ago. (similarity: \(hit.similarity))")
#endif // DEBUG

			// match the tuneurl
			DispatchQueue.main.async {
				AudioMatcher.shared.recognizedTrigger(timeRelativeToNow: secondsAgo)
			}
		}
	}

	/// Slide the trigger across the most recent triggerWindowDuration of audio.
	///
	/// Decides with the high-passed window against the trigger references
	/// (high-passed trigger plus echoey copies). Also scores the previous
	/// check (unfiltered window, trigger only) and logs both side by side.
	private func searchForTrigger(label: String) -> TriggerLook? {
		// copy the sound data from the buffer
		guard let bufferData = audioBuffer.copyBufferData(maxDuration: triggerWindowDuration) else {
			return nil
		}
		let now = Date()

		// resample to the fingerprint sample rate
		guard let resampledData = AudioUtility.changeSampleRate(sampleRate: FINGERPRINT_SAMPLE_RATE, buffer1: bufferData) else {
			return nil
		}
		let windowSeconds = Double(resampledData.count) / FINGERPRINT_SAMPLE_RATE
		let filteredData = AudioUtility.highPassed(resampledData)

		return AudioMatcher.shared.withTrigger { triggerFingerprint, triggerSampleCount, references, labels -> TriggerLook? in
			guard let triggerFingerprint = triggerFingerprint, triggerSampleCount > 0 else {
				return nil
			}

			// previous check, for comparison only
			let previous = AudioUtility.slideTrigger(
				over: resampledData,
				triggerFingerprint: triggerFingerprint,
				triggerSampleCount: triggerSampleCount,
				hopSeconds: triggerSlideHop
			)

			// new check: high-passed window against every reference
			let current = AudioUtility.slideTrigger(
				over: filteredData,
				references: references,
				triggerSampleCount: triggerSampleCount,
				hopSeconds: triggerSlideHop
			)

			let previousScore: Float = previous?.similarity ?? 0
			let newScore: Float = current?.match.similarity ?? 0
			var referenceLabel = "none"
			if let index = current?.referenceIndex, index < labels.count {
				referenceLabel = labels[index]
			}
			let verdict = (newScore > triggerThreshold) ? "PASS" : "-"
			let previousVerdict = (previousScore > previousTriggerThreshold) ? "pass" : "-"
			let startTime: Float = current?.match.startTime ?? 0
			let positions: Int = current?.match.positionsChecked ?? 0

			// Diagnostic — visible in Release builds and in the app via Listener.diagnosticHandler
			Diagnostics.log(String(format: "TuneURL_DIAG: ota local new=%.2f %@ (pass >%.2f, ref %@) old=%.2f %@ triggerStart=%.2fs window=%.2fs positions=%ld%@",
			                       newScore, verdict, triggerThreshold, referenceLabel,
			                       previousScore, previousVerdict,
			                       startTime, windowSeconds, positions, label))

			// the previous check decides only if the references could not be built
			if references.isEmpty {
				guard let previous = previous else {
					return nil
				}
				let secondsAgo = windowSeconds - Double(previous.startTime)
				return TriggerLook(similarity: previousScore, triggerStart: now.addingTimeInterval(-secondsAgo),
				                   passed: previousScore > previousTriggerThreshold)
			}

			guard let match = current?.match else {
				return nil
			}
			let secondsAgo = windowSeconds - Double(match.startTime)
			return TriggerLook(similarity: match.similarity, triggerStart: now.addingTimeInterval(-secondsAgo),
			                   passed: match.similarity > triggerThreshold)
		}
	}

	private func convertAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
		// setup the converted audio buffer
        guard
            let converter = audioConverter,
            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: bufferFormat,
                frameCapacity: AVAudioFrameCount(bufferFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)
            )
        else { return nil }
        
        // process the buffer with the audio converter
		var error: NSError?
		var newBufferAvailable = true
		converter.convert(to: convertedBuffer, error: &error) {
			inNumPackets, outStatus in

			if newBufferAvailable {
				outStatus.pointee = .haveData
				newBufferAvailable = false
				return buffer
			} else {
				outStatus.pointee = .noDataNow
				return nil
			}
		}

		if (convertedBuffer.frameLength == 0) {
			return nil
		}

		return convertedBuffer
	}

	private func setupAudioSession() {
		do {
			try audioSession.setCategory(
			    .playAndRecord,
			    // .measurement turns off iOS input processing (automatic gain,
			    // noise suppression) so the trigger reaches the fingerprinter unaltered
			    mode: .measurement,
			    options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
			)
			try audioSession.setActive(true)
			try audioSession.setPreferredSampleRate(44100.0)
			try audioSession.setPreferredInputNumberOfChannels(1)
			if #available(iOS 13.0, *) {
				try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
			}
		} catch {
			NSLog("TuneURL: Error setting up audio session. (\(error.localizedDescription))")
		}
	}

	private func startAudioEngine() -> Bool {
		// setup the input node
		let inputNode = audioEngine.inputNode
		let inputFormat = inputNode.inputFormat(forBus: 0)

		// check if we need the buffer conversion
		useBufferConversion = (inputFormat.isEqual(bufferFormat) == false)

		// setup audio conversion
		if useBufferConversion {
			guard let converter = AVAudioConverter(from: inputFormat, to: bufferFormat) else {
				return false
			}
			audioConverter = converter
		}

		// setup the input node to deliver sample buffers
		inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: {
			(sourceBuffer: AVAudioPCMBuffer!, time: AVAudioTime!) in

			var buffer: AVAudioPCMBuffer?

			if self.useBufferConversion {
				buffer = self.convertAudioBuffer(sourceBuffer)
			} else {
				buffer = sourceBuffer
			}

			if let buffer = buffer {
			    // add the audio to the audio buffer
			    self.audioBuffer.appendSampleBuffer(buffer)
			    // check every 2s with the 4s window → 2s overlap, no trigger falls in a gap
			    if (self.audioBuffer.untestedTime > 2.0) {
			        // reset immediately to prevent next frame from trigger detection
			        self.audioBuffer.resetUntestedSize()
			        self.detectionQueue.async {
			            // run detection
			            self.checkForTriggerSound()
			        }
			    }
			}

			// pass the buffer to speech recognition
			AudioMatcher.shared.audioBufferDelegate?(sourceBuffer)
		})

		audioEngine.mainMixerNode.outputVolume = 0.0
		audioEngine.prepare()

		// start the audio engine
		do {
			try audioEngine.start()
		} catch {
			Diagnostics.log("TuneURL_DIAG: ota microphone failed to start (\(error.localizedDescription))")
			return false
		}

		Diagnostics.log(String(format: "TuneURL_DIAG: ota microphone started (input %.0f Hz, %ld channel(s), mode %@)",
		                       inputFormat.sampleRate, Int(inputFormat.channelCount), audioSession.mode.rawValue))
		return true
	}

	private func stopAudioEngine() {
		// stop the audio engine
		audioEngine.stop()
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.reset()

		// release any audio converter
		audioConverter = nil
	}

	// MARK: - AVAudioEngine notifications
	@objc private func audioEngineConfigurationChange(_ notification: Notification) {
#if DEBUG
		print("TuneURL: audioEngineConfigurationChange")
#endif // DEBUG

		// make sure the audio engine is stopped
		stopAudioEngine()

		// restart the audio engine
		if (startAudioEngine() == false) {
			NSLog("TuneURL: Error restarting the audio engine.")
		}

		// notify the delegate
		delegate?.audioCaptureStatusChanged()
	}
}
