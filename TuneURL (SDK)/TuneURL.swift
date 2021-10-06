//
//  TuneURL.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/27/21.
//  Copyright © 2021 TuneURL Inc. All rights reserved.
//


import Foundation


public class TuneURL {

	typealias MatchHandler = (MatchResponse) -> Void

	public static var isListening: Bool {
		get {
			return AudioMatcher.shared.isRunning
		}
	}

	public static var speechDelegate: AudioMatcherSpeechDelegate? {
		get {
			return AudioMatcher.shared.speechDelegate
		}
		set {
			return AudioMatcher.shared.speechDelegate = newValue
		}
	}

	public static func startListening(matchHandler: @escaping (MatchResponse) -> Void)
	{
		AudioMatcher.shared.start(matchHandler: matchHandler)
	}

	public static func stopListening()
	{
		AudioMatcher.shared.stop()
	}

}
