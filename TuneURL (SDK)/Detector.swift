//
//  Detector.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 10/27/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import Foundation
import AVFoundation
@_implementationOnly import Fingerprint_Private

public class Detector {
    
    // MARK: - Types
    public typealias CompletionHandler = ([Match]) -> Void
    
    private class DetectRequest {
        let completionHandler: CompletionHandler
		var possibleMatches = [PossibleMatch]()
		var matches = [Match]()

		init(completionHandler: @escaping CompletionHandler) {
			self.completionHandler = completionHandler
		}
	}

	private struct PossibleMatch {
		var fingerprint: [UInt8]
		var time: Float
	}

	// MARK: - Private props
	private static let dispatchQueue = DispatchQueue(label: "TuneURL Detector")
	private static var triggerFingerprint: UnsafeMutablePointer<Fingerprint>?
	private static let triggerWindowDuration = 4.0

	// MARK: - Public static funcs
	public static func setTrigger(_ audioFileURL: URL) {
		dispatchQueue.async {
			privateSetTrigger(audioFileURL)
		}
	}

	public static func processAudio(for audioFileURL: URL, completionHandler: @escaping CompletionHandler) {
		dispatchQueue.async {
			privateProcessAudio(for: audioFileURL, completionHandler: completionHandler)
		}
	}

    // MARK: - Private funcs
    private static func privateSetTrigger(_ audioFileURL: URL) {
		// clear any current trigger
		FingerprintFree(triggerFingerprint)
		triggerFingerprint = nil

		// create the trigger fingerprint
		if let fingerprint = AudioUtility.generateFingerprint(for: audioFileURL) {
			triggerFingerprint = fingerprint
		}
	}

	private static func privateProcessAudio(for audioFileURL: URL, completionHandler: @escaping CompletionHandler) {
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
		let fingerprintBytesPerSecond = 160   // 5 fps × 4 landmarks/frame × 8 bytes/landmark
		let windowSize = (fingerprintBytesPerSecond * Int(triggerWindowDuration))
		let fileFingerprintSize = Int(fileFingerprint.pointee.dataSize)
		let totalMatchSize = Int((triggerDuration + matchDuration) * Float(fingerprintBytesPerSecond))

		while (currentIndex <= (fileFingerprintSize - totalMatchSize)) {
			// create the window fingerprint
			var windowFingerprint = Fingerprint(data: fileFingerprint.pointee.data.advanced(by: currentIndex), dataSize: Int32(windowSize))

			// compare the fingerprints
			let matchResults = CompareFingerprints(&windowFingerprint, triggerFingerprint)

			// Note: This uses a very high similarity because the audio should really
			// be an almost exact match from a podcast.

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
					// check if the possible match is too close to the last one
					if let lastPossibleMatch = detectRequest.possibleMatches.last {
						if (abs(lastPossibleMatch.time - possibleMatch.time) > 0.5) {
							detectRequest.possibleMatches.append(possibleMatch)
						} else {
#if DEBUG
							print("Ignoring possible match.")
#endif // DEBUG
						}
					} else {
						// there are no other possible matches
						detectRequest.possibleMatches.append(possibleMatch)
					}
				} else {
#if DEBUG
					print("Error: Match is too close to the end of the file.")
#endif // DEBUG
				}
			}

			// advance, but overlap the trigger window
			currentIndex += (windowSize >> 1)
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

	private static func requestNext(_ detectRequest: DetectRequest) {
		// pop the last possible match
		guard let possibleMatch = detectRequest.possibleMatches.popLast() else {
			// sort the results
			detectRequest.matches.sort { (match1, match2) -> Bool in
				return (match1.time < match2.time)
			}
			// call the completion handler
			detectRequest.completionHandler(detectRequest.matches)
			return
		}

		// make the server request
		Server.shared.matchFingerprint(for: possibleMatch.fingerprint, queue: dispatchQueue) {
			match in

			// add the server match
			if let match = match {
				detectRequest.matches.append(Match(match: match, time: possibleMatch.time))
			}

			// process the next possible match
			requestNext(detectRequest)
		}
	}
}
