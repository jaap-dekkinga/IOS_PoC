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
