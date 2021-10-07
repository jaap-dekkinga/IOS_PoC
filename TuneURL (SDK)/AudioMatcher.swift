//
//  AudioMatcher.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/12/19.
//  Copyright © 2019-2021 TuneURL Inc. All rights reserved.
//


import AVFoundation
import Fingerprint
import Foundation


class AudioMatcher {

	// static
	static let shared = AudioMatcher()

	// public
	var audioBufferDelegate: TuneURL.AudioBufferHandler?

	// public (read-only)
	public private(set) var audioCapture: AudioCapture?
	public private(set) var isRunning = false
	public private(set) var triggerFingerprint: UnsafeMutablePointer<Fingerprint>?

	// private
	private let audioBuffer: AudioBuffer
	private var matchHandler: TuneURL.MatchHandler?

	// MARK: -

	init()
	{
		// setup the audio buffer
		audioBuffer = AudioBuffer(captureDuration: 10.0, sampleRate: 44100.0)
		audioBuffer.reset()

		// setup the audio trigger
		prepareAudioTrigger()
	}

	deinit
	{
		FingerprintFree(triggerFingerprint)
		triggerFingerprint = nil
	}

	// MARK: - Public

	func start(matchHandler: @escaping TuneURL.MatchHandler)
	{
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

	func stop()
	{
		// stop audio capture
		audioCapture?.stop()
		audioCapture = nil

		// cleanup
		matchHandler = nil
		isRunning = false
	}

	// MARK: -

	func recognizedSound(timeRelativeToNow: Float)
	{
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
				  let matchFingerprint = ExtractFingerprint(matchResampledBuffer, Int32(matchResampledBuffer.count)) else {
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
#endif // DEBUG

			// create the match fingerprint data
			var matchFingerprintData = [UInt8]()
			let pointer = matchFingerprint.pointee.data!
			for x in 0 ..< Int(matchFingerprint.pointee.dataSize) {
				matchFingerprintData.append(pointer[x])
			}

			// ask the server to match the audio
			MatchServer.shared.requestMatch(for: matchFingerprintData) {
				(response: MatchResponse?) in
				// notfiy the delegate on a successful match
				if let matchResponse = response, let handler = self.matchHandler {
					handler(matchResponse)
				}
			}

			// cleanup
			FingerprintFree(matchFingerprint)
		}
	}

	// MARK: - Private

	private func generateFingerprint(for fileURL: URL, resample: Bool) -> UnsafeMutablePointer<Fingerprint>?
	{
		var result: OSStatus = noErr
		var audioFile: AudioFileID?
		var propertyDataSize: UInt32 = 8
		var dataSize: UInt64 = 0

		result = AudioFileOpenURL(fileURL as CFURL, .readPermission, kAudioFileAIFFType, &audioFile)
		if (result != noErr) {
			NSLog("TuneURL: Error opening audio file. (\(result))")
			return nil
		}

		result = AudioFileGetProperty(audioFile!, kAudioFilePropertyAudioDataByteCount, &propertyDataSize, &dataSize)
		if (result != noErr) {
			NSLog("TuneURL: Error getting audio file property. (\(result))")
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
			NSLog("TuneURL: Error reading audio file packet data. (\(result))")
			return nil
		}

		result = AudioFileClose(audioFile!)
		if (result != noErr) {
			NSLog("TuneURL: Error closing audio file. (\(result))")
		}

		// resample the audio
		let resampled: [Int16]
		if (resample) {
			let sampleRate = FINGERPRINT_SAMPLE_RATE
			guard let buffer = AudioUtility.changeSampleRate(sampleRate: Double(sampleRate), buffer1: dataBuffer) else {
				return nil
			}
			resampled = buffer
		} else {
			resampled = dataBuffer
		}

		if let fingerprint = ExtractFingerprint(resampled, Int32(resampled.count)) {
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

	private func startMatching()
	{
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
