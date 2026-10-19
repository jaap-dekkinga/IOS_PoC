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
		var matchSamples: [Int16]   // raw audio for the match segment — kept for V1 fallback
		var time: Float
	}

	// MARK: - Private props

	private static let dispatchQueue = DispatchQueue(label: "TuneURL Detector")
	private static var triggerFingerprint: UnsafeMutablePointer<Fingerprint>?
	private static var triggerSampleCount = 0
	// File scan: the trigger is slid across the decoded file in steps of this
	// many seconds (see AudioUtility.slideTrigger), as the live/radio path does.
	private static let triggerSlideHop = 0.25
	// Pass mark for a file-scan hit. A trigger scores ~1.0; speech peaks ~0.5.
	private static let fileTriggerThreshold: Float = 0.75
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
		triggerSampleCount = 0
		if let trigger = AudioUtility.generateTriggerFingerprint(for: audioFileURL) {
			NSLog("[SDK-DIAG] trigger fingerprint set (sliding file scan, \(trigger.sampleCount) samples)")
			triggerFingerprint = trigger.fingerprint
			triggerSampleCount = trigger.sampleCount
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

		// Find triggers by sliding a trigger-length slice across the whole file
		// in triggerSlideHop steps — the same search the live/radio path uses
		// (AudioUtility.slideTrigger). The previous scan compared fixed 4 s
		// windows, stepped every 2 s, against the ~1.4 s trigger; CompareFingerprints
		// then only looked at the start of each window, so a trigger that began
		// late in a window (e.g. 1.5 s in) scored ~0.35 and was missed.
		let detectRequest = DetectRequest(completionHandler: completionHandler)
		let matchDuration: Double = 5.0
		let triggerDuration: Double = 2.0
		let matchSampleCount = Int((triggerDuration + matchDuration) * sampleRate)
		let sliceCount = triggerSampleCount
		let hopSampleCount = max(1, Int(triggerSlideHop * sampleRate))
		let triggerSeconds = Double(sliceCount) / sampleRate

		guard sliceCount > 0, let triggerFingerprint, totalSampleCount >= sliceCount else {
			NSLog("[SDK-DIAG] scan skipped: trigger samples=\(sliceCount) file samples=\(totalSampleCount)")
			completionHandler([])
			return
		}

		NSLog("[SDK-DIAG] scan start totalSamples=\(totalSampleCount) sliceSamples=\(sliceCount) hop=\(triggerSlideHop)s matchSamples=\(matchSampleCount)")

		// (time, similarity) of each trigger found; neighbouring slices that see
		// the same trigger are merged, keeping the best-scoring one
		var hits = [(time: Double, similarity: Float)]()
		var diagMaxSimilarity: Float = 0.0
		var diagMaxSimilarityAt: Double = 0.0
		var positions = 0
		var offset = 0

		while (offset + sliceCount) <= totalSampleCount {
			if let slice = ExtractFingerprint(int16Data[0].advanced(by: offset), Int32(sliceCount), Int32(FORMAT_VERSION_V2)) {
				let result = CompareFingerprints(slice, triggerFingerprint)
				FingerprintFree(slice)

				// mostSimilarStartTime is relative to the slice; it is a huge
				// negative number when nothing matched, so ignore implausible values
				let inSlice = (abs(Double(result.mostSimilarStartTime)) <= triggerSeconds) ? Double(result.mostSimilarStartTime) : 0.0
				let time = (Double(offset) / sampleRate) + inSlice

				if result.similarity > diagMaxSimilarity {
					diagMaxSimilarity = result.similarity
					diagMaxSimilarityAt = time
				}

				if result.similarity > fileTriggerThreshold {
					if let last = hits.last, (time - last.time) < (triggerSeconds + 1.0) {
						if result.similarity > last.similarity {
							hits[hits.count - 1] = (time, result.similarity)
						}
					} else {
						hits.append((time, result.similarity))
					}
				}
			}
			positions += 1
			offset += hopSampleCount
		}

		NSLog("[SDK-DIAG] scan complete positions=\(positions) maxSimilarity=\(diagMaxSimilarity) atTime=\(String(format: "%.2f", diagMaxSimilarityAt))s threshold=\(fileTriggerThreshold) triggers=\(hits.count)")

		for hit in hits {
#if DEBUG
			print("TuneURL: Trigger detected at: \(hit.time) seconds (similarity: \(hit.similarity))")
#endif // DEBUG
			NSLog("[SDK-DIAG] trigger at \(String(format: "%.2f", hit.time))s similarity=\(hit.similarity)")

			// the identifiable audio starts triggerDuration after the trigger starts
			let matchStartSample = Int((hit.time + triggerDuration) * sampleRate)
			let matchEndSample = min(matchStartSample + matchSampleCount, totalSampleCount)
			guard (matchEndSample > matchStartSample), (matchStartSample >= 0) else {
				NSLog("[SDK-DIAG] trigger at \(String(format: "%.2f", hit.time))s is too close to the end of the file")
				continue
			}

			let matchSamples = Array(UnsafeBufferPointer(start: int16Data[0].advanced(by: matchStartSample), count: (matchEndSample - matchStartSample)))
			guard let matchFingerprint = ExtractFingerprint(matchSamples, Int32(matchSamples.count), Int32(FORMAT_VERSION_V1)) else {
				continue
			}
			var fingerprintData = [UInt8]()
			let pointer = matchFingerprint.pointee.data!
			for x in 0 ..< Int(matchFingerprint.pointee.dataSize) {
				fingerprintData.append(pointer[x])
			}
			FingerprintFree(matchFingerprint)

			// V1 fingerprint primary, matchSamples kept for the V2 fallback in requestNext
			detectRequest.possibleMatches.append(PossibleMatch(fingerprint: fingerprintData, matchSamples: matchSamples, time: Float(hit.time)))
		}

		// nothing to look up: report no matches once (requestNext would report again)
		if detectRequest.possibleMatches.isEmpty {
			completionHandler([])
			return
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

		// ask the server to match the audio — V1 primary, V2 fallback.
		// (Note: this is the opposite order from AudioMatcher's live/radio
		// path, which is V2 primary/V1 fallback — intentional per app:
		// the trigger sound itself stays V2, only match-segment
		// identification here is V1-first.)
		Server.shared.matchFingerprint(for: possibleMatch.fingerprint, queue: dispatchQueue) {
			match in

			if let match = match {
				match.fingerprintVersion = "V1"
				detectRequest.matches.append(Match(match: match, time: possibleMatch.time))
				requestNext(detectRequest)
				return
			}

			// V1 returned no match — fall back to V2 once
#if DEBUG
			print("TuneURL: V1 match returned nil, retrying with V2 fingerprint.")
#endif
			guard let v2Fingerprint = ExtractFingerprint(
				possibleMatch.matchSamples,
				Int32(possibleMatch.matchSamples.count),
				Int32(FORMAT_VERSION_V2)
			) else {
				requestNext(detectRequest)
				return
			}

			var v2Data = [UInt8]()
			let v2Pointer = v2Fingerprint.pointee.data!
			for x in 0 ..< Int(v2Fingerprint.pointee.dataSize) {
				v2Data.append(v2Pointer[x])
			}
			FingerprintFree(v2Fingerprint)

			Server.shared.matchFingerprint(for: v2Data, queue: dispatchQueue) { (fallbackMatch: Match?) in
				if let fallbackMatch = fallbackMatch {
					fallbackMatch.fingerprintVersion = "V2"
					detectRequest.matches.append(Match(match: fallbackMatch, time: possibleMatch.time))
				}
				// process the next possible match either way
				requestNext(detectRequest)
			}
		}
	}
}
