//
//  AudioCapture.swift
//  AudioTriggerPOC
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/2/19.
//  Copyright © 2019. All rights reserved.
//


import AVFoundation
import Foundation


protocol AudioCaptureDelegate {

	func audioCaptureStatusChanged()

}

// MARK: -

class AudioCapture: NSObject {

	// private
	private let audioBuffer: AudioBuffer
	private let audioEngine = AVAudioEngine()
	private let audioSession = AVAudioSession.sharedInstance()
	private var delegate: AudioCaptureDelegate?
	private let sampleRate: Double

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
		audioEngine.stop()
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.reset()

		// stop the audio buffer
		audioBuffer.stopRecording()

//		// stop the audio session
//		_ = try? audioSession.setActive(false)

		// notify the delegate
		delegate?.audioCaptureStatusChanged()
	}

	// MARK: -
	// MARK: Private

	private func setupAudioSession()
	{
		do {
			try audioSession.setCategory(.playAndRecord, mode: .default)
			try audioSession.setActive(true)
		} catch {
			NSLog("AudioCapture: Error setting up audio session. (\(error.localizedDescription))")
		}
	}

	private func startAudioEngine() -> Bool
	{
		// setup the input node
		let inputNode = audioEngine.inputNode
		let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false)
		audioEngine.connect(inputNode, to: audioEngine.outputNode, format: inputFormat)

		// setup the input node to deliver sample buffers
		inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat, block: {
			(buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
			// add the audio to the audio buffer
			self.audioBuffer.appendSampleBuffer(buffer)
		})

		audioEngine.mainMixerNode.outputVolume = 0.0
		audioEngine.prepare()

		// start the audio engine
		do {
			try audioEngine.start()
		} catch {
			NSLog("AudioCapture: Error starting audio engine. (\(error))")
			return false
		}

		return true
	}

	// MARK: -
	// MARK: AVAudioEngine notifications

	@objc func audioEngineConfigurationChange(_ notification: Notification)
	{
		NSLog("AudioCapture: audioEngineConfigurationChange")

		// restart the audio engine
		if (startAudioEngine() == false) {
			NSLog("AudioCapture: Error restarting the audio engine.")
		}

		// notify the delegate
		delegate?.audioCaptureStatusChanged()
	}

}
