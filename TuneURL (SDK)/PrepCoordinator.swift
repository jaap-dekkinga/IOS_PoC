//
//  PrepCoordinator.swift
//  TuneURL (SDK)
//
//  Wires PodcastPrepDetector into the app: decodes a completed download
//  (BatchDecodeFeed) into append(_:) calls, and reacts to resolved
//  TuneUrlMoments (PrepCoordinator), including recursive prep for CYON
//  default branches.
//
//  Built against DownloadCache.swift's real API (Alamofire-based,
//  full-download-then-local-URL — no partial/progressive file access).
//
//  STAND-INS STILL TO SWAP FOR YOUR REAL EQUIVALENTS:
//   - AudioUtility.convertToFingerprintSamples(_:) — whatever StreamDetector
//     already uses to get mic input into fingerprint format (mono, Int16,
//     FINGERPRINT_SAMPLE_RATE) — reuse that, don't rewrite it.
//   - TriggerStore.shared.fingerprint — the one global trigger, per your
//     earlier answer that it's a single fixed clip for the whole app.
//   - PrepStore.shared — wherever TuneUrlMoments/PrepStatus get persisted
//     per branch (per the Data Model in the design doc).
//   - CYONOption needs a `playerItem: PlayerItem` field (not a raw audioURL)
//     to match DownloadCache.cachedFile(for:completion:)'s signature.
//

import Foundation
import AVFoundation
@_implementationOnly import Fingerprint_Private

// MARK: - Decode feed

protocol DecodeAheadFeedDelegate: AnyObject {
    func decodeAheadFeed(_ feed: BatchDecodeFeed, didDecode samples: [Int16])
    func decodeAheadFeedReachedEnd(_ feed: BatchDecodeFeed)
}

/// DownloadCache (Alamofire's AF.download) only hands back a URL once the
/// file is FULLY downloaded — there's no partial/growing file to poll, so
/// this decodes the complete local file in chunks. Still feeds the detector
/// progressively (not one giant blocking call) so moments resolve as
/// scanning proceeds and CYON-default prep can start before the whole
/// episode finishes scanning. "Ahead of the playhead" now means starting
/// this whole pipeline as early as possible (e.g. when an episode is
/// queued), not racing partial download bytes.
final class BatchDecodeFeed {

    weak var delegate: DecodeAheadFeedDelegate?

    private let fileURL: URL
    private let chunkDuration: Double = 2.0
    private let queue = DispatchQueue(label: "com.TuneURL.BatchDecodeFeed-\(UUID().uuidString)")

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func start() {
        queue.async { self.decodeAll() }
    }

    private func decodeAll() {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else {
            NSLog("TuneURL: Unable to open downloaded file for Prep scanning. (\(fileURL.lastPathComponent))")
            delegate?.decodeAheadFeedReachedEnd(self)
            return
        }

        let frameCount = AVAudioFrameCount(chunkDuration * audioFile.processingFormat.sampleRate)
        while audioFile.framePosition < audioFile.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: frameCount) else { break }
            do {
                try audioFile.read(into: buffer, frameCount: frameCount)
            } catch {
                break   // stop on read error rather than looping forever
            }
            guard let samples = AudioUtility.convertToFingerprintSamples(buffer) else { continue }
            delegate?.decodeAheadFeed(self, didDecode: samples)
        }

        delegate?.decodeAheadFeedReachedEnd(self)
    }
}

// MARK: - Prep coordinator (delegate hookup)

final class PrepCoordinator: PodcastPrepDetectorDelegate, DecodeAheadFeedDelegate {

    let branchId: String
    private let detector: PodcastPrepDetector
    private let feed: BatchDecodeFeed
    private let settings: PrepSettings

    // recursive prep for CYON default branches — keyed by option id so we
    // don't kick off the same branch's prep twice
    private static var activeCoordinators: [String: PrepCoordinator] = [:]
    private static let activeCoordinatorsQueue = DispatchQueue(label: "com.TuneURL.PrepCoordinator.registry")

    /// fileURL must already be a completed local download (e.g. from
    /// DownloadCache.cachedFile / DownloadCache.download's completion).
    init(branchId: String, fileURL: URL, settings: PrepSettings = PrepSettings()) {
        self.branchId = branchId
        self.settings = settings
        self.detector = PodcastPrepDetector(triggerFingerprint: TriggerStore.shared.fingerprint, settings: settings)
        self.feed = BatchDecodeFeed(fileURL: fileURL)
        detector.delegate = self
        feed.delegate = self
    }

    func start() {
        feed.start()
    }

    // MARK: - DecodeAheadFeedDelegate — just bridges into the detector

    func decodeAheadFeed(_ feed: BatchDecodeFeed, didDecode samples: [Int16]) {
        detector.append(samples)
    }

    func decodeAheadFeedReachedEnd(_ feed: BatchDecodeFeed) {
        detector.markEndOfStream()
    }

    // MARK: - PodcastPrepDetectorDelegate

    func prepDetector(_ detector: PodcastPrepDetector, didResolve moment: TuneUrlMoment) {
        PrepStore.shared.save(moment, forBranch: branchId)

        // CYON moment — kick off prep for the default option's audio now,
        // in the background, well ahead of the listener reaching this point
        if let options = moment.match.options, !options.isEmpty,
           let defaultOption = options.first(where: { $0.isDefault }) {
            beginPrepForDefaultBranch(defaultOption)
        }
    }

    func prepDetector(_ detector: PodcastPrepDetector, scannedUpTo time: TimeInterval) {
        PrepStore.shared.updateScannedUpTo(time, forBranch: branchId)
        // Playback side should check PrepStore's scannedUpTo vs. its own
        // currentTime + leadTimeSeconds before trusting a moment is resolved —
        // that lead-time check belongs in the player, not here.
    }

    func prepDetectorReachedEndOfStream(_ detector: PodcastPrepDetector) {
        PrepStore.shared.markComplete(forBranch: branchId)
        Self.activeCoordinatorsQueue.async {
            Self.activeCoordinators[self.branchId] = nil
        }
    }

    /// option must resolve to a PlayerItem (podcast + episode) — CYONOption
    /// needs a playerItem field rather than a raw audioURL, to match
    /// DownloadCache's actual API.
    private func beginPrepForDefaultBranch(_ option: CYONOption) {
        Self.activeCoordinatorsQueue.async {
            guard Self.activeCoordinators[option.id] == nil else { return }   // already prepping

            // cachedFile evicts older non-user-download cache entries past
            // maxCachedItems (5) — worth revisiting whether Prep-prefetched
            // branches need protection from eviction before they're played
            DownloadCache.shared.cachedFile(for: option.playerItem) { localURL in
                guard let localURL else { return }
                let coordinator = PrepCoordinator(branchId: option.id, fileURL: localURL, settings: self.settings)
                Self.activeCoordinators[option.id] = coordinator
                coordinator.start()
            }
        }
    }
}
