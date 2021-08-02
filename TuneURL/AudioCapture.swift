//
//  AudioCapture.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/2/19.
//  Copyright © 2019-2021 TuneURL Inc. All rights reserved.
//


import AVFoundation
import Foundation


protocol AudioCaptureDelegate {

	func audioCaptureStatusChanged()

}

protocol AudioCaptureSpeechDelegate {

	func audioCaptureBuffer(buffer: AVAudioPCMBuffer)

}

// MARK: -

class AudioCapture: NSObject {

	// public
	var speechDelegate: AudioCaptureSpeechDelegate?

	// private
	private let audioBuffer: AudioBuffer
	private var audioConverter: AVAudioConverter?
	private let audioEngine = AVAudioEngine()
	private let audioSession = AVAudioSession.sharedInstance()
	private let bufferFormat: AVAudioFormat
	private var delegate: AudioCaptureDelegate?
	private let sampleRate: Double
	private let triggerWindowDuration = 4.0
	private var useBufferConversion = false

	// computed
	var isRunning: Bool {
		return audioEngine.isRunning
	}

	// MARK: -

	init(audioBuffer buffer: AudioBuffer, sampleRate rate: Double, delegate: AudioCaptureDelegate?)
	{
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

	deinit
	{
		// make sure recording has stopped
		stop()
	}

	// MARK: -

	func start() -> Bool
	{
		// safety check
		if self.isRunning {
			return true
		}

		// start the audio buffer
		audioBuffer.startRecording()

		// setup the audio session
		setupAudioSession()

		// start the audio engine
		if (startAudioEngine() == false) {
			return false
		}

		// setup the configuration change notification
		let notificationCenter = NotificationCenter.default
		notificationCenter.addObserver(self, selector: #selector(audioEngineConfigurationChange), name: .AVAudioEngineConfigurationChange, object: audioEngine)

		return true
	}

	func stop()
	{
		// stop notifications
		NotificationCenter.default.removeObserver(self, name: nil, object: audioEngine)

		// stop the audio engine
		stopAudioEngine()

		// stop the audio buffer
		audioBuffer.stopRecording()

		// stop the audio session
		_ = try? audioSession.setActive(false)

		// notify the delegate
		delegate?.audioCaptureStatusChanged()
	}

	// MARK: -
	// MARK: Private

	private func checkForTriggerSound()
	{
		// TODO: move this into the audio matcher

		audioBuffer.resetUntestedSize()

		// copy the sound data from the buffer
		guard let bufferData = audioBuffer.copyBufferData(maxDuration: triggerWindowDuration) else {
			return
		}

		// resample the fingerprint
		let sampleRate = FINGERPRINT_SAMPLE_RATE
		guard let resampledData = AudioUtility.changeSampleRate(sampleRate: sampleRate, buffer1: bufferData) else {
			return
		}

		// generate a fingerprint
		guard let bufferFingerprint = ExtractFingerprint(resampledData, Int32(resampledData.count)) else {
			return
		}

		// get the trigger fingerprint
		let audioMatcher = AppDelegate.audioMatcher
		let triggerFingerprint = audioMatcher.triggerFingerprint

		// calculate the fingerprint match results
		let matchResults = CompareFingerprints(bufferFingerprint, triggerFingerprint)
		FingerprintFree(bufferFingerprint)

		// check the match results
		if (matchResults.similarity > 0.1) {

			// calculate the time of the sound relative to now
			let mostSimilarStartingTime = matchResults.mostSimilarStartTime
			let relativeTime = (Float(triggerWindowDuration) - mostSimilarStartingTime)
#if DEBUG
			print("AudioCapture: Detected trigger \(relativeTime) seconds ago. (similarity: \(matchResults.similarity))")
#endif // DEBUG

			// match the tune url
			let audioMatcher = AppDelegate.audioMatcher
			audioMatcher.recognizedSound(timeRelativeToNow: relativeTime)

#if DEBUG
			// dump fingerprint data
			var string = ""
			string += "\tFingerprint score: \(matchResults.score)\n"
			string += "\tFingerprint similarity: \(matchResults.similarity)\n"
			string += "\tFingerprint similar time: \(matchResults.mostSimilarStartTime)\n"
			string += "\tFingerprint most similar frame: \(matchResults.mostSimilarFramePosition)\n"
			print(string)

			// create the file name
			let recordingFolderURL = AppDelegate.recordingFolderURL
			let format = DateFormatter()
			format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
			let filename = "Matched-\(format.string(from: Date()))"

			// write the match results
			let resultsFileURL = recordingFolderURL.appendingPathComponent(filename + ".txt")
			_ = try? string.write(to: resultsFileURL, atomically: true, encoding: .utf8)

			// write the match sound
			let fingerprintFileURL = recordingFolderURL.appendingPathComponent(filename + ".aif")
			_ = try? AudioUtility.writeAudioFile(to: fingerprintFileURL, buffer: bufferData, sampleRate: 44100.0)
#endif // DEBUG
		} else {
#if DEBUG
			print("AudioCapture: Checked for trigger sound. (similarity: \(matchResults.similarity))")
#endif // DEBUG
		}
	}

	private func convertAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer?
	{
		// setup the converted audio buffer
		guard let converter = audioConverter,
			let convertedBuffer = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: AVAudioFrameCount(bufferFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)) else {
			return nil
		}

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

	private func setupAudioSession()
	{
		do {
			try audioSession.setCategory(.playAndRecord, mode: .default)
			try audioSession.setActive(true)
			try audioSession.setPreferredSampleRate(44100.0)
			try audioSession.setPreferredInputNumberOfChannels(1)
			if #available(iOS 13.0, *) {
				try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
			}
		} catch {
			NSLog("AudioCapture: Error setting up audio session. (\(error.localizedDescription))")
		}
	}

	private func startAudioEngine() -> Bool
	{
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
				// check if we have 5 seconds of data to test
				if (self.audioBuffer.untestedTime > 5.0) {
					// reset immediately to prevent next frame from trigger detection
					self.audioBuffer.resetUntestedSize()
					DispatchQueue.main.async {
						// run detection
						self.checkForTriggerSound()
					}
				}
			}

			// pass the buffer to speech recognition
			self.speechDelegate?.audioCaptureBuffer(buffer: sourceBuffer)
		})

		audioEngine.mainMixerNode.outputVolume = 0.0
		audioEngine.prepare()

		// start the audio engine
		do {
			try audioEngine.start()
		} catch {
			NSLog("AudioCapture: Error starting audio engine. (\(error.localizedDescription))")
			return false
		}

		return true
	}

	private func stopAudioEngine()
	{
		// stop the audio engine
		audioEngine.stop()
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.reset()

		// release any audio converter
		audioConverter = nil
	}

	// MARK: -
	// MARK: AVAudioEngine notifications

	@objc func audioEngineConfigurationChange(_ notification: Notification)
	{
		NSLog("AudioCapture: audioEngineConfigurationChange")

		// make sure the audio engine is stopped
		stopAudioEngine()

		// restart the audio engine
		if (startAudioEngine() == false) {
			NSLog("AudioCapture: Error restarting the audio engine.")
		}

		// notify the delegate
		delegate?.audioCaptureStatusChanged()
	}

}
