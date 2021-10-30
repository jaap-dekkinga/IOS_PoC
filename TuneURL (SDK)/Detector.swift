//
//  Detector.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 10/27/21.
//  Copyright © 2021 TuneURL Inc. All rights reserved.
//


import AVFoundation
import Fingerprint_Private
import Foundation


public class Detector {

	// types
	public typealias CompletionHandler = ([MatchResponse]) -> Void

	private class DetectRequest {
		let completionHandler: CompletionHandler
		var possibleMatches = [PossibleMatch]()
		var matches = [MatchResponse]()

		init(completionHandler: @escaping CompletionHandler) {
			self.completionHandler = completionHandler
		}
	}

	private struct PossibleMatch {
		var fingerprint: [UInt8]
		var time: Float
	}

	// private
	private static let dispatchQueue = DispatchQueue(label: "TuneURL Detector")
	private static var triggerFingerprint: UnsafeMutablePointer<Fingerprint>?
	private static let triggerWindowDuration = 4.0

	// MARK: - Public

	public static func setTrigger(_ audioFileURL: URL)
	{
		dispatchQueue.async {
			privateSetTrigger(audioFileURL)
		}
	}

	public static func processAudio(for audioFileURL: URL, completionHandler: @escaping CompletionHandler)
	{
		dispatchQueue.async {
			privateProcessAudio(for: audioFileURL, completionHandler: completionHandler)
		}
	}

	// MARK: - Private

	public static func privateSetTrigger(_ audioFileURL: URL)
	{
		// clear any current trigger
		FingerprintFree(triggerFingerprint)
		triggerFingerprint = nil

		// create the trigger fingerprint
		if let fingerprint = AudioUtility.generateFingerprint(for: audioFileURL) {
			triggerFingerprint = fingerprint
		}
	}

	private static func privateProcessAudio(for audioFileURL: URL, completionHandler: @escaping CompletionHandler)
	{
		// safety check
		guard (triggerFingerprint != nil) else {
			NSLog("TuneURL: Error: No audio trigger has been set.")
			return
		}

		// create the fingerprint for the file
		guard let fileFingerprint = AudioUtility.generateFingerprint(for: audioFileURL) else {
			completionHandler([])
			return
		}

		// process the file fingerprint
		var currentIndex = 0
		let detectRequest = DetectRequest(completionHandler: completionHandler)
		let matchDuration: Float = 5.0
		let triggerDuration: Float = 2.0
		let triggerWindowDuration: Float = 4.0
		let fingerprintBytesPerSecond = 640	// TODO: confirm this
		let windowSize = (fingerprintBytesPerSecond * Int(triggerWindowDuration))

		while (currentIndex < fileFingerprint.pointee.dataSize) {
			// create the window fingerprint
			var windowFingerprint = Fingerprint(data: fileFingerprint.pointee.data.advanced(by: currentIndex), dataSize: Int32(windowSize))

			// compare the fingerprints
			let matchResults = CompareFingerprints(&windowFingerprint, triggerFingerprint, false)

			// Note: This uses a very high similarity because the audio should really be an
			// almost exact match from a podcast.

			// check the match results
			if (matchResults.similarity > 0.75) {
	#if DEBUG
				// dump the trigger match results
				print("TuneURL: Trigger detected at: \(matchResults.mostSimilarStartTime) seconds (similarity: \(matchResults.similarity))")
				print("\tTrigger fingerprint score: \(matchResults.score)")
				print("\tTrigger fingerprint similarity: \(matchResults.similarity)")
				print("\tTrigger fingerprint similar time: \(matchResults.mostSimilarStartTime)")
				print("\tTrigger fingerprint most similar frame: \(matchResults.mostSimilarFramePosition)")
	#endif // DEBUG

				// calculate the match fingerprint
				var matchStartBytes = Int((matchResults.mostSimilarStartTime + triggerDuration) * Float(fingerprintBytesPerSecond))
				matchStartBytes = (matchStartBytes - (matchStartBytes % 32))
				var matchEndBytes = (matchStartBytes + Int(matchDuration * Float(fingerprintBytesPerSecond)))
				matchEndBytes = (matchEndBytes - (matchEndBytes % 32))

				// create the possible match
				if (matchEndBytes < fileFingerprint.pointee.dataSize) {
					// copy the possible match fingerprint data
					var fingerprintData = [UInt8]()
					let fingerprintDataSize = (matchEndBytes - matchStartBytes)
					let pointer = fileFingerprint.pointee.data.advanced(by: matchStartBytes)
					for x in 0 ..< fingerprintDataSize {
						fingerprintData.append(pointer[x])
					}

					// add the possible match
					let possibleMatch = PossibleMatch(fingerprint: fingerprintData, time: matchResults.mostSimilarStartTime)
					detectRequest.possibleMatches.append(possibleMatch)
				} else {
					print("Error: Match is too close to the end of the file.")
				}
			}

			// TODO: overlap the trigger window
//			currentIndex += (windowSize >> 1)
			currentIndex += windowSize
		}

		// cleanup
		FingerprintFree(fileFingerprint)

		// safety check
		if (detectRequest.possibleMatches.count == 0) {
			detectRequest.completionHandler([])
		}

		// start making server requests
		requestNext(detectRequest)
	}

	private static func requestNext(_ detectRequest: DetectRequest)
	{
		// pop the last possible match
		guard let possibleMatch = detectRequest.possibleMatches.popLast() else {
			detectRequest.completionHandler(detectRequest.matches)
			return
		}

		// make the server request
		Server.shared.matchFingerprint(for: possibleMatch.fingerprint, queue: dispatchQueue) {
			matchResponse in

			// add the server match
			if let matchResponse = matchResponse {
				detectRequest.matches.append(matchResponse)
			}

			// process the next possible match
			requestNext(detectRequest)
		}
	}

}
