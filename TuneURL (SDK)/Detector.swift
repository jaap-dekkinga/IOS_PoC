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

		// decode + resample the whole file to raw audio (same decode path
		// AudioUtility.generateFingerprint uses internally) — but instead of
		// collapsing it into a single fingerprint and slicing its bytes for
		// "windows" (which produced near-zero similarity even for a slice of
		// the trigger against itself — see FIX #3 below), fingerprint each
		// window FRESH from raw audio samples, exactly like
		// AudioCapture.checkForTriggerSound() already does for the live/radio
		// path. Same fingerprinting logic, just looped over a fully-decoded
		// buffer instead of a live rolling one.
		guard let audioBuffer = AudioUtility.prepareAudioForProcessing(audioFileURL, asFloat: false),
			  let int16Data = audioBuffer.int16ChannelData else {
			NSLog("[SDK-DIAG] file audio decode FAILED for \(audioFileURL.lastPathComponent)")
			completionHandler([])
			return
		}

		let totalSampleCount = Int(audioBuffer.frameLength)
		let sampleRate = FINGERPRINT_SAMPLE_RATE   // already resampled to this by prepareAudioForProcessing

		// >>> SDK-DIAG: header + whole-file comparison sanity check ------------
		// whole-buffer fingerprint, for the sanity-check log only — the
		// windowed scan below never slices this, it re-extracts per window.
		let wholeSamples = Array(UnsafeBufferPointer(start: int16Data[0], count: totalSampleCount))
		if let wholeFingerprint = ExtractFingerprint(wholeSamples, Int32(wholeSamples.count), Int32(FORMAT_VERSION_V2)) {
			if let tp = triggerFingerprint {
				let tb = tp.pointee.data!
				NSLog("[SDK-DIAG] trigger size=\(tp.pointee.dataSize) first8=\(String(format: "%02X %02X %02X %02X %02X %02X %02X %02X", tb[0], tb[1], tb[2], tb[3], tb[4], tb[5], tb[6], tb[7]))")
			}
			let fb = wholeFingerprint.pointee.data!
			NSLog("[SDK-DIAG] file    size=\(wholeFingerprint.pointee.dataSize) first8=\(String(format: "%02X %02X %02X %02X %02X %02X %02X %02X", fb[0], fb[1], fb[2], fb[3], fb[4], fb[5], fb[6], fb[7]))")

			let wholeCompare = CompareFingerprints(wholeFingerprint, triggerFingerprint)
			NSLog("[SDK-DIAG] whole-file compare similarity=\(wholeCompare.similarity) atTime=\(wholeCompare.mostSimilarStartTime)s score=\(wholeCompare.score)")
			FingerprintFree(wholeFingerprint)
		}
		// <<< end SDK-DIAG ----------------------------------------------------

		// process the audio in a sliding window, fingerprinting each window
		// fresh from raw audio samples
		var currentSample = 0
		let detectRequest = DetectRequest(completionHandler: completionHandler)
		let matchDuration: Double = 5.0
		let triggerDuration: Double = 2.0
		let triggerWindowDuration: Double = 4.0

		let windowSampleCount = Int(triggerWindowDuration * sampleRate)
		let stepSampleCount = (windowSampleCount / 2)   // 50% overlap
		let matchSampleCount = Int((triggerDuration + matchDuration) * sampleRate)

		// >>> SDK-DIAG: max-similarity trackers
		var diagMaxSimilarity: Float = 0.0
		var diagMaxSimilarityAt: Float = 0.0
		var diagIterations = 0
		// <<<

		NSLog("[SDK-DIAG] scan start totalSamples=\(totalSampleCount) windowSamples=\(windowSampleCount) matchSamples=\(matchSampleCount)")

		while ((currentSample + windowSampleCount) <= totalSampleCount) {
			// fresh raw-audio window, fingerprinted from scratch — same as
			// AudioCapture.checkForTriggerSound(), not a slice of a
			// pre-existing fingerprint's bytes
			let windowPointer = int16Data[0].advanced(by: currentSample)
			let windowSamples = Array(UnsafeBufferPointer(start: windowPointer, count: windowSampleCount))

			guard let windowFingerprint = ExtractFingerprint(windowSamples, Int32(windowSamples.count), Int32(FORMAT_VERSION_V2)) else {
				currentSample += stepSampleCount
				continue
			}

			// compare the fingerprints
			let matchResults = CompareFingerprints(windowFingerprint, triggerFingerprint)
			FingerprintFree(windowFingerprint)

			// >>> SDK-DIAG: track the highest similarity seen
			if matchResults.similarity > diagMaxSimilarity {
				diagMaxSimilarity = matchResults.similarity
				diagMaxSimilarityAt = matchResults.mostSimilarStartTime
			}
			diagIterations += 1
			// <<<

			// Note: This uses a very high similarity because the audio should really
			// be an almost exact match from a podcast.
			if (matchResults.similarity > 0.75) {
#if DEBUG
				print("TuneURL: Trigger detected at: \(matchResults.mostSimilarStartTime) seconds (similarity: \(matchResults.similarity))")
				print("\tTrigger fingerprint score: \(matchResults.score)")
				print("\tTrigger fingerprint similarity: \(matchResults.similarity)")
				print("\tTrigger fingerprint similar time: \(matchResults.mostSimilarStartTime)")
				print("\tTrigger fingerprint most similar frame: \(matchResults.mostSimilarFramePosition)")
#endif // DEBUG

				// absolute time of the hit within the whole file
				let hitTime = (Double(currentSample) / sampleRate) + Double(matchResults.mostSimilarStartTime)

				// extract raw audio for identification and fingerprint it
				// fresh too — same reasoning as the window scan above
				let matchStartSample = Int((hitTime + triggerDuration) * sampleRate)
				let matchEndSample = min(matchStartSample + matchSampleCount, totalSampleCount)

				if (matchEndSample > matchStartSample) && (matchStartSample >= 0) {
					let matchPointer = int16Data[0].advanced(by: matchStartSample)
					let matchSamples = Array(UnsafeBufferPointer(start: matchPointer, count: (matchEndSample - matchStartSample)))

					if let matchFingerprint = ExtractFingerprint(matchSamples, Int32(matchSamples.count), Int32(FORMAT_VERSION_V2)) {
						var fingerprintData = [UInt8]()
						let pointer = matchFingerprint.pointee.data!
						for x in 0 ..< Int(matchFingerprint.pointee.dataSize) {
							fingerprintData.append(pointer[x])
						}
						FingerprintFree(matchFingerprint)

						// add the possible match
						let possibleMatch = PossibleMatch(fingerprint: fingerprintData, time: Float(hitTime))
						// check if the possible match is too close to the last one
						if let lastPossibleMatch = detectRequest.possibleMatches.last {
							if (abs(Double(lastPossibleMatch.time) - hitTime) > 0.5) {
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
					}
				} else {
#if DEBUG
					print("Error: Match is too close to the end of the file.")
#endif // DEBUG
				}
			}

			// advance, but overlap the trigger window
			currentSample += stepSampleCount
		}

		// >>> SDK-DIAG: report what the scan actually saw
		NSLog("[SDK-DIAG] scan complete iterations=\(diagIterations) maxSimilarity=\(diagMaxSimilarity) atTime=\(diagMaxSimilarityAt)s threshold=0.75 possibleMatches=\(detectRequest.possibleMatches.count)")
		// <<<

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
