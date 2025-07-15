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

	// MARK: - Functions
    public static func setTrigger(_ audioFileURL: URL)
    {
        AudioMatcher.shared.privateSetTrigger(from: audioFileURL)
    }
    
	public static func startListening(matchHandler: @escaping (Match) -> Void)
	{
		AudioMatcher.shared.start(matchHandler: matchHandler)
	}

	public static func stopListening()
	{
		AudioMatcher.shared.stop()
	}

}
