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
		// Log which SDK build is running (helps distinguish CI vs local builds)
		NSLog("[SDK-INFO] TuneURL SDK build=\(SDK_BUILD_TIMESTAMP) commit=\(SDK_BUILD_COMMIT)")

		// clear any current trigger
		FingerprintFree(triggerFingerprint)
		triggerFingerprint = nil

		// create the trigger fingerprint
		if let fingerprint = AudioUtility.generateFingerprint(for: audioFileURL) {
			NSLog("[SDK-DIAG] trigger fingerprint set july 24 2026")
			triggerFingerprint = fingerprint
		} else {
			NSLog("[SDK-DIAG] trigger fingerprint FAILED — generateFingerprint returned nil for \(audioFileURL.lastPathComponent)")
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
			NSLog("[SDK-DIAG] file fingerprint FAILED — generateFingerprint returned nil for \(audioFileURL.lastPathComponent)")
			completionHandler([])
			return
		}

		// >>> SDK-DIAG: header + whole-file comparison sanity check ------------
		// This block is a diagnostic added to isolate whether the zero-similarity
		// bug lives in (a) fingerprint generation, (b) CompareFingerprints itself,
		// or (c) the sliding-window slice construction below. Safe to leave in;
		// remove once detection is validated end-to-end.
		if let tp = triggerFingerprint {
			let tb = tp.pointee.data!
			NSLog("[SDK-DIAG] trigger size=\(tp.pointee.dataSize) first8=\(String(format: "%02X %02X %02X %02X %02X %02X %02X %02X", tb[0], tb[1], tb[2], tb[3], tb[4], tb[5], tb[6], tb[7]))")
		}
		let fb = fileFingerprint.pointee.data!
		NSLog("[SDK-DIAG] file    size=\(fileFingerprint.pointee.dataSize) first8=\(String(format: "%02X %02X %02X %02X %02X %02X %02X %02X", fb[0], fb[1], fb[2], fb[3], fb[4], fb[5], fb[6], fb[7]))")

		var wholeFileFP = Fingerprint(data: fileFingerprint.pointee.data, dataSize: fileFingerprint.pointee.dataSize)
		let wholeCompare = CompareFingerprints(&wholeFileFP, triggerFingerprint)
		NSLog("[SDK-DIAG] whole-file compare similarity=\(wholeCompare.similarity) atTime=\(wholeCompare.mostSimilarStartTime)s score=\(wholeCompare.score)")
		// <<< end SDK-DIAG ----------------------------------------------------

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

		// >>> SDK-DIAG: max-similarity trackers
		var diagMaxSimilarity: Float = 0.0
		var diagMaxSimilarityAt: Float = 0.0
		var diagIterations = 0
		// <<<

		NSLog("[SDK-DIAG] scan start fileFingerprintSize=\(fileFingerprintSize) windowSize=\(windowSize) totalMatchSize=\(totalMatchSize)")

		while (currentIndex <= (fileFingerprintSize - totalMatchSize)) {
			// create the window fingerprint
			var windowFingerprint = Fingerprint(data: fileFingerprint.pointee.data.advanced(by: currentIndex), dataSize: Int32(windowSize))

			// compare the fingerprints
			let matchResults = CompareFingerprints(&windowFingerprint, triggerFingerprint)

			// >>> SDK-DIAG: track the highest similarity seen
			if matchResults.similarity > diagMaxSimilarity {
				diagMaxSimilarity = matchResults.similarity
				diagMaxSimilarityAt = matchResults.mostSimilarStartTime
			}
			diagIterations += 1
			// <<<

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

		// >>> SDK-DIAG: report what the scan actually saw
		NSLog("[SDK-DIAG] scan complete iterations=\(diagIterations) maxSimilarity=\(diagMaxSimilarity) atTime=\(diagMaxSimilarityAt)s threshold=0.75 possibleMatches=\(detectRequest.possibleMatches.count)")
		// <<<

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
