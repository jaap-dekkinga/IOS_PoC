//
//  PodcastPrepDetector.swift
//  TuneURL (SDK)
//
//  Incremental "Prep phase" trigger-sound scanner for progressively
//  downloaded podcast audio. Reuses Detector.swift's windowed-scan logic
//  (sequential windows, 50% overlap, dedupe) but drives it from a buffer
//  that grows as audio is decoded ahead of the playhead, instead of
//  requiring the whole file up front.
//
//  Feed this from a decode-ahead pipeline (see design notes) via append(_:).
//  It is NOT tied to real time — call append(_:) as fast as decoded PCM
//  becomes available.
//

import Foundation
import AVFoundation
@_implementationOnly import Fingerprint_Private

public struct TuneUrlMoment {
    public let timestamp: TimeInterval     // absolute position in this audio stream
    public let match: Match                // API response / CTA payload
}

public struct PrepSettings {
    public var minimumMomentSpacingSeconds: Double = 0.5   // promote to a real app setting
    public var matchThreshold: Float = 0.75                 // keep consistent everywhere —
                                                             // StreamDetector currently uses 0.1,
                                                             // which is inconsistent and should be aligned
    public init() {}
}

public protocol PodcastPrepDetectorDelegate: AnyObject {
    func prepDetector(_ detector: PodcastPrepDetector, didResolve moment: TuneUrlMoment)
    func prepDetector(_ detector: PodcastPrepDetector, scannedUpTo time: TimeInterval)
    func prepDetectorReachedEndOfStream(_ detector: PodcastPrepDetector)
}

public class PodcastPrepDetector {

    // MARK: - Public

    public weak var delegate: PodcastPrepDetectorDelegate?
    public private(set) var scannedUpToTime: TimeInterval = 0

    public init(triggerFingerprint: UnsafeMutablePointer<Fingerprint>, settings: PrepSettings = PrepSettings()) {
        self.triggerFingerprint = triggerFingerprint
        self.settings = settings
    }

    /// Feed decoded PCM (mono, FINGERPRINT_SAMPLE_RATE, 16-bit) as it becomes
    /// available from the decode-ahead pipeline. Can arrive much faster than
    /// real time — the scanner just keeps up as fast as the CPU allows.
    public func append(_ samples: [Int16]) {
        queue.async { self.privateAppend(samples) }
    }

    /// Call once the decode-ahead pipeline has reached the end of the file.
    public func markEndOfStream() {
        queue.async {
            self.reachedEndOfStream = true
            self.pump()
        }
    }

    // MARK: - Private state

    private let queue = DispatchQueue(label: "com.TuneURL.PodcastPrepDetector-\(UUID().uuidString)")
    private let triggerFingerprint: UnsafeMutablePointer<Fingerprint>
    private let settings: PrepSettings

    // Growing raw-audio accumulator for this branch's audio (whole-episode
    // sized buffers are fine in memory at fingerprinting sample rates).
    private var accumulatedSamples: [Int16] = []
    private var fingerprintedSampleCount = 0          // how much of accumulatedSamples has been fingerprinted
    private var currentFingerprint: UnsafeMutablePointer<Fingerprint>?
    private var currentIndex = 0                       // scan position, in fingerprint bytes — persists across pump() calls
    private var reachedEndOfStream = false
    private var lastResolvedMomentTime: TimeInterval?
    private var pendingHitFingerprintIndex: Int?        // detected, waiting on trailing audio to extract

    // Same constants as Detector.swift
    private let fingerprintBytesPerSecond = 160
    private let windowSize = 640          // 4.0s
    private let triggerDuration: Float = 2.0
    private let matchDuration: Float = 5.0
    private var totalMatchSize: Int { Int((triggerDuration + matchDuration) * Float(fingerprintBytesPerSecond)) }

    // MARK: - Core loop

    private func privateAppend(_ samples: [Int16]) {
        accumulatedSamples.append(contentsOf: samples)
        refreshFingerprintIfNeeded()
        pump()
    }

    /// Re-fingerprint the accumulated raw audio when there's enough new audio
    /// to be worth it. (Re-fingerprinting the whole buffer each time is
    /// simplest and correctness-safe; throttle here if it becomes a CPU
    /// concern for very long episodes — verify with Gerrit whether
    /// ExtractFingerprint supports incremental append instead of recompute.)
    private func refreshFingerprintIfNeeded() {
        let newSampleCount = (accumulatedSamples.count - fingerprintedSampleCount)
        let newSeconds = Double(newSampleCount) / Double(FINGERPRINT_SAMPLE_RATE)
        guard newSeconds >= 1.0 || reachedEndOfStream else { return }

        if let old = currentFingerprint {
            FingerprintFree(old)
        }
        currentFingerprint = accumulatedSamples.withUnsafeBufferPointer { ptr in
            ExtractFingerprint(Array(ptr), Int32(accumulatedSamples.count), Int32(FORMAT_VERSION_V2))
        }
        fingerprintedSampleCount = accumulatedSamples.count
    }

    private func pump() {
        guard let fp = currentFingerprint else { return }
        let fileFingerprintSize = Int(fp.pointee.dataSize)

        // 1) resolve a pending hit once enough trailing audio has arrived
        if let hitIndex = pendingHitFingerprintIndex {
            let neededSize = hitIndex + totalMatchSize
            if fileFingerprintSize >= neededSize || reachedEndOfStream {
                resolvePendingHit(atFingerprintIndex: hitIndex, fingerprint: fp, availableSize: fileFingerprintSize)
                pendingHitFingerprintIndex = nil
            } else {
                // not enough trailing audio yet — wait for more append() calls,
                // do NOT advance the scan past this point
                return
            }
        }

        // 2) sequential windowed scan — same overlap/loop shape as Detector.swift,
        //    but bounded by what's currently available, not the final file size.
        //    "not enough remaining yet" pauses here and resumes on the next
        //    pump() call once more audio has arrived — it is never treated as
        //    "no match" the way the batch version's loop bound effectively did.
        while (currentIndex + windowSize) <= fileFingerprintSize {
            scanWindow(at: currentIndex, fingerprint: fp)
            if pendingHitFingerprintIndex != nil { break }   // stop scanning until this hit is resolved
            currentIndex += (windowSize >> 1)
        }

        scannedUpToTime = Double(currentIndex) / Double(fingerprintBytesPerSecond)
        delegate?.prepDetector(self, scannedUpTo: scannedUpToTime)

        if reachedEndOfStream && pendingHitFingerprintIndex == nil && (currentIndex + windowSize) > fileFingerprintSize {
            delegate?.prepDetectorReachedEndOfStream(self)
        }
    }

    private func scanWindow(at index: Int, fingerprint: UnsafeMutablePointer<Fingerprint>) {
        var windowFingerprint = Fingerprint(data: fingerprint.pointee.data.advanced(by: index), dataSize: Int32(windowSize))
        let matchResults = CompareFingerprints(&windowFingerprint, triggerFingerprint)

        guard matchResults.similarity > settings.matchThreshold else { return }

        let absoluteTime = (Double(index) / Double(fingerprintBytesPerSecond)) + Double(matchResults.mostSimilarStartTime)

        if let last = lastResolvedMomentTime, abs(last - absoluteTime) < settings.minimumMomentSpacingSeconds {
            return   // too close to the last resolved moment — dedupe
        }

        pendingHitFingerprintIndex = index
    }

    private func resolvePendingHit(atFingerprintIndex hitIndex: Int, fingerprint: UnsafeMutablePointer<Fingerprint>, availableSize: Int) {
        // extract whatever's available, up to totalMatchSize — if we hit
        // end-of-stream with less than that, use what exists rather than
        // dropping the moment (handles a trigger near the very end of a branch)
        let extractSize = min(totalMatchSize, availableSize - hitIndex)
        guard extractSize > (Int(triggerDuration) * fingerprintBytesPerSecond) else {
            return   // not enough trailing audio even at end of stream to be useful
        }

        var segmentData = [UInt8]()
        let pointer = fingerprint.pointee.data.advanced(by: hitIndex)
        for i in 0..<extractSize {
            segmentData.append(pointer[i])
        }

        let absoluteTime = Double(hitIndex) / Double(fingerprintBytesPerSecond)
        lastResolvedMomentTime = absoluteTime

        Server.shared.matchFingerprint(for: segmentData, queue: queue) { [weak self] match in
            guard let self, let match else { return }
            let moment = TuneUrlMoment(timestamp: absoluteTime, match: match)
            self.delegate?.prepDetector(self, didResolve: moment)
            // Caller's delegate is responsible for checking moment for CYON +
            // kicking off a new PodcastPrepDetector for the default branch's
            // audio, recursively, per the Prep spec.
        }
    }

    deinit {
        if let fp = currentFingerprint {
            FingerprintFree(fp)
        }
    }
}
