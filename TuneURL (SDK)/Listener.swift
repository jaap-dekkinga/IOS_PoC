//
//  Listener.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/27/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import AVFoundation
import Foundation

public class Listener {

	public typealias AudioBufferHandler = (AVAudioPCMBuffer) -> Void
	public typealias MatchHandler = (Match) -> Void

	// MARK: - Properties

	public static var isListening: Bool {
		get {
			return AudioMatcher.shared.isRunning
		}
	}

	public static var audioBufferDelegate: AudioBufferHandler? {
		get {
			return AudioMatcher.shared.audioBufferDelegate
		}
		set {
			return AudioMatcher.shared.audioBufferDelegate = newValue
		}
	}

	/// Receives the SDK's diagnostic lines: trigger scores from each check,
	/// recognitions, and what the server answered. Called on the main thread.
	/// Lines are also written with NSLog, as before. Set to nil to stop.
	public static var diagnosticHandler: ((String) -> Void)? {
		get {
			return Diagnostics.handler
		}
		set {
			Diagnostics.handler = newValue
		}
	}

	// MARK: - Sound gate

	/// Over-the-air listening only reacts when the room has steady sound,
	/// such as a radio playing nearby. In a quiet room a single clink or knock
	/// can resemble the trigger closely enough to pass, so the trigger check
	/// is skipped there (which also saves battery), and audio after a detected
	/// trigger is only sent to the server when it is not quiet either.
	/// On by default.
	public static var soundGateEnabled: Bool {
		get { return SoundGate.settings.enabled }
		set { SoundGate.update { $0.enabled = newValue } }
	}

	/// A 100 ms slice of microphone audio counts as sound when its level is
	/// at least this loud, in dBFS (0 is the loudest possible, -50 is quiet
	/// background). Default -50.
	public static var soundGateMinimumLevel: Float {
		get { return SoundGate.settings.minimumLevel }
		set { SoundGate.update { $0.minimumLevel = newValue } }
	}

	/// Share of the slices (0.0 to 1.0) that must count as sound. Music and
	/// speech fill most slices; a clink or a knock in a quiet room fills only
	/// one or two. Default 0.5.
	public static var soundGateMinimumActiveFraction: Float {
		get { return SoundGate.settings.minimumActiveFraction }
		set { SoundGate.update { $0.minimumActiveFraction = min(max(newValue, 0), 1) } }
	}

	// MARK: - Functions
    public static func setTrigger(_ audioFileURL: URL) {
        AudioMatcher.shared.privateSetTrigger(from: audioFileURL)
    }
    
	public static func startListening(matchHandler: @escaping (Match) -> Void) {
		AudioMatcher.shared.start(matchHandler: matchHandler)
	}

	public static func stopListening() {
		AudioMatcher.shared.stop()
	}
}

// MARK: - Sound gate settings

/// Settings for the over-the-air sound gate. They are set from the app and
/// read on the detection queue, so access goes through a lock.
enum SoundGate {

	struct Settings {
		var enabled = true
		var minimumLevel: Float = -50.0
		var minimumActiveFraction: Float = 0.5
	}

	private static let lock = NSLock()
	private static var storedSettings = Settings()

	static var settings: Settings {
		lock.lock()
		defer { lock.unlock() }
		return storedSettings
	}

	static func update(_ change: (inout Settings) -> Void) {
		lock.lock()
		change(&storedSettings)
		lock.unlock()
	}

	/// Checks microphone `samples` against the current settings. Returns nil
	/// when the gate is off, otherwise the measurement and whether it passed.
	static func check(_ samples: [Int16], sampleRate: Double) -> (presence: AudioUtility.SoundPresence, passed: Bool)? {
		let current = settings
		guard current.enabled else { return nil }
		let presence = AudioUtility.soundPresence(of: samples, sampleRate: sampleRate, minimumLevel: current.minimumLevel)
		return (presence, presence.activeFraction >= current.minimumActiveFraction)
	}

	/// One diagnostic line describing a measurement.
	static func describe(_ presence: AudioUtility.SoundPresence) -> String {
		let current = settings
		return String(format: "sound=%.2f (need %.2f above %.0f dBFS) median=%.0f dBFS loudest=%.0f dBFS",
		              presence.activeFraction, current.minimumActiveFraction, current.minimumLevel,
		              presence.medianLevel, presence.loudestLevel)
	}
}

// MARK: - Diagnostics

/// Writes a diagnostic line with NSLog (visible in Release builds) and
/// passes it to `Listener.diagnosticHandler` on the main thread.
enum Diagnostics {

	private static let lock = NSLock()
	private static var storedHandler: ((String) -> Void)?

	static var handler: ((String) -> Void)? {
		get {
			lock.lock()
			defer { lock.unlock() }
			return storedHandler
		}
		set {
			lock.lock()
			storedHandler = newValue
			lock.unlock()
		}
	}

	static func log(_ message: String) {
		NSLog("%@", message)
		if let handler = handler {
			DispatchQueue.main.async {
				handler(message)
			}
		}
	}
}
