//
//  StreamDetector.swift
//  TuneURL
//
//  Copyright © 2025 TuneURL Inc. All rights reserved.
//

import Foundation
import AVFoundation
@_implementationOnly import Fingerprint_Private

public class StreamDetector {
    
    // MARK: - Public props
    public var matchCallback: ((Match) -> Void)?
    
    // MARK: - Private props
    private let dispatchQueue = DispatchQueue(label: "com.TuneURL.StreamDetector-\(UUID().uuidString)")
    private var triggerFingerprint: UnsafeMutablePointer<Fingerprint>?
    private var triggerSampleCount = 0
    // High-passed trigger (see AudioUtility.makeTriggerReferences, no echo
    // copies). The check decides with this; nil if it could not be built.
    private var filteredTriggerFingerprint: UnsafeMutablePointer<Fingerprint>?
    private let triggerWindowDuration = 4.0

    // Trigger search: the trigger is slid across the window in steps of
    // triggerSlideHop seconds (see AudioUtility.slideTrigger).
    private let triggerSlideHop = 0.125
    // Pass marks. Scores come in steps of 0.04.
    // Filtered check (900 Hz high-pass on window and trigger): "> 0.18" accepts
    // 0.20 and up, the same pass mark as the microphone check.
    private let triggerThreshold: Float = 0.18
    // Previous check (unfiltered): "> 0.1" accepts 0.12 and up. Still scored
    // and logged for comparison; it decides only if the filtered trigger
    // could not be built.
    private let previousTriggerThreshold: Float = 0.1
    // One trigger is visible on 2-3 consecutive checks; ignore further hits
    // for this long after a detection.
    private let triggerCooldown: TimeInterval = 6.0
    // After a first hit, look again this much later and keep the better match.
    private let triggerReLookDelay: TimeInterval = 1.0
    private var lastTriggerTime = Date.distantPast
    private var isConfirmingTrigger = false
    // A check has been queued but not run yet. Without this, every buffer that
    // arrives before the check runs queues another check on almost the same
    // window, and one trigger can be recognised (and sent to the server) twice.
    private var isCheckPending = false
    
    private let audioBuffer: AudioBuffer
    private let bufferFormat: AVAudioFormat

    private var cachedAudioConverter: AVAudioConverter?
    
    public init(_ triggerURL: URL) {
        self.audioBuffer = AudioBuffer(
            captureDuration: 10.0,
            sampleRate: 44100.0
        )
        self.audioBuffer.reset()
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100.0,
            channels: 1,
            interleaved: false
        ) else {
            fatalError("Error creating audio buffer format.")
        }
        bufferFormat = format
        
        dispatchQueue.async {
            self.privateSetTrigger(triggerURL)
        }
    }
    
    deinit {
        dispatchQueue.sync {
            audioBuffer.reset()
            FingerprintFree(triggerFingerprint)
            triggerFingerprint = nil
            FingerprintFree(filteredTriggerFingerprint)
            filteredTriggerFingerprint = nil
        }
    }
    
    // MARK: - Public funcs
    public func append(_ buffer: AVAudioPCMBuffer) {
        dispatchQueue.async {
            let normalizedBuffer: AVAudioPCMBuffer
            if buffer.format != self.bufferFormat {
                guard
                    let converter = self.audioConverter(from: buffer.format),
                    let convertedBuffer = self.convertAudioBuffer(buffer, converter)
                else { return }
                normalizedBuffer = convertedBuffer
            } else {
                normalizedBuffer = buffer
            }

            self.audioBuffer.appendSampleBuffer(normalizedBuffer)
            //NSLog("TuneURL_DIAG: untestedTime=%.3f", self.audioBuffer.untestedTime)
            if self.audioBuffer.untestedTime > 2.0 && !self.isCheckPending {
                self.isCheckPending = true
                self.dispatchQueue.async {
                    self.checkForTriggerSound()
                }
            }
        }
     }
    
    public func reset() {
        dispatchQueue.async {
            self.audioBuffer.reset()
        }
    }
    
    // MARK: - Private funcs
    /// One local search: how well the trigger matched and when it started.
    private struct TriggerLook {
        let similarity: Float
        let triggerStart: Date
        let passed: Bool
    }

    private func checkForTriggerSound() {
        isCheckPending = false
        audioBuffer.resetUntestedSize()

        // one trigger is visible on several consecutive checks
        if isConfirmingTrigger || Date().timeIntervalSince(lastTriggerTime) < triggerCooldown {
            return
        }

        guard let firstLook = searchForTrigger(label: ""), firstLook.passed else {
            return
        }

        lastTriggerTime = Date()
        isConfirmingTrigger = true

        // look once more when the trigger is fully in view, keep the better match
        dispatchQueue.asyncAfter(deadline: .now() + triggerReLookDelay) {
            self.isConfirmingTrigger = false

            var hit = firstLook
            if let secondLook = self.searchForTrigger(label: " (re-look)"), secondLook.similarity > firstLook.similarity {
                hit = secondLook
            }

            let secondsAgo = Float(Date().timeIntervalSince(hit.triggerStart))
#if DEBUG
            print("TuneURL: Trigger detected \(secondsAgo) seconds ago. (similarity: \(hit.similarity))")
#endif // DEBUG

            // match the tuneurl
            self.recognizedTrigger(timeRelativeToNow: secondsAgo)
        }
    }

    /// Slide the trigger across the most recent triggerWindowDuration of audio.
    ///
    /// Decides with the high-passed window against the high-passed trigger.
    /// Below 900 Hz the window holds mostly music bass, which otherwise takes
    /// the fingerprint's points from the trigger when the song plays under it
    /// (test of 2026-11-05: unfiltered 0.12 at best, filtered 1.00). Also
    /// scores the previous check (unfiltered) and logs both side by side.
    private func searchForTrigger(label: String) -> TriggerLook? {
        guard let triggerFingerprint, triggerSampleCount > 0 else {
            return nil
        }

        // copy the sound data from the buffer
        guard let bufferData = audioBuffer.copyBufferData(maxDuration: triggerWindowDuration) else {
            return nil
        }
        let now = Date()

        // resample to the fingerprint sample rate
        guard let resampledData = AudioUtility.changeSampleRate(sampleRate: FINGERPRINT_SAMPLE_RATE, buffer1: bufferData) else {
            return nil
        }
        let windowSeconds = Double(resampledData.count) / FINGERPRINT_SAMPLE_RATE

        // previous check, for comparison (decides only without a filtered trigger)
        let previous = AudioUtility.slideTrigger(
            over: resampledData,
            triggerFingerprint: triggerFingerprint,
            triggerSampleCount: triggerSampleCount,
            hopSeconds: triggerSlideHop
        )
        let previousScore: Float = previous?.similarity ?? 0
        let previousVerdict = (previousScore > previousTriggerThreshold) ? "pass" : "-"

        // new check: high-passed window against the high-passed trigger
        var current: AudioUtility.SlidingMatch?
        if let filteredTriggerFingerprint {
            current = AudioUtility.slideTrigger(
                over: AudioUtility.highPassed(resampledData),
                triggerFingerprint: filteredTriggerFingerprint,
                triggerSampleCount: triggerSampleCount,
                hopSeconds: triggerSlideHop
            )
        }
        let newScore: Float = current?.similarity ?? 0
        let verdict = (newScore > triggerThreshold) ? "PASS" : "-"

        let decider = (filteredTriggerFingerprint != nil) ? current : previous
        let startTime: Float = decider?.startTime ?? 0
        let positions: Int = decider?.positionsChecked ?? 0

        // Diagnostic — visible in Release builds and in the app via Listener.diagnosticHandler
        Diagnostics.log(String(format: "TuneURL_DIAG: stream local new=%.2f %@ (pass >%.2f) old=%.2f %@ triggerStart=%.2fs window=%.2fs positions=%ld%@",
                               newScore, verdict, triggerThreshold,
                               previousScore, previousVerdict,
                               startTime, windowSeconds, positions, label))

        guard let match = decider else {
            return nil
        }
        let passed = (filteredTriggerFingerprint != nil)
            ? match.similarity > triggerThreshold
            : match.similarity > previousTriggerThreshold
        let secondsAgo = windowSeconds - Double(match.startTime)
        return TriggerLook(similarity: match.similarity, triggerStart: now.addingTimeInterval(-secondsAgo), passed: passed)
    }

    func recognizedTrigger(timeRelativeToNow: Float) {
#if DEBUG
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        let currentTime = formatter.string(from: Date())
        print("TuneURL: (\(currentTime)): Did Recognize: window time: \(-timeRelativeToNow) seconds ago")
#endif // DEBUG
        
        // calculate how much of the sample has already been recorded
        let triggerSoundDuration = 2.0
        // Note: adding a half second of audio to the identifiable audio section to accomodate
        // processing time.
        let identifiableAudioDuration = 5.0
        let recordedSampleDuration = (Double(timeRelativeToNow) - triggerSoundDuration)
        var remainingTimeToRecord = (identifiableAudioDuration - recordedSampleDuration)
        remainingTimeToRecord = max(remainingTimeToRecord, 0.0)
        
        dispatchQueue.asyncAfter(deadline: (.now() + remainingTimeToRecord)) {
            // create the tuneurl fingerprint
            guard
                let matchAudioBuffer = self.audioBuffer.copyBufferData(maxDuration: identifiableAudioDuration),
                let matchResampledBuffer = AudioUtility.changeSampleRate(sampleRate: FINGERPRINT_SAMPLE_RATE, buffer1: matchAudioBuffer),
                let matchFingerprint = ExtractFingerprint(matchResampledBuffer, Int32(matchResampledBuffer.count), Int32(FORMAT_VERSION_V2))
            else {
                return
            }
            
#if DEBUG
            print("matchAudioBuffer size: \(matchAudioBuffer.count)")
            print("matchResampledBuffer size: \(matchResampledBuffer.count)")
            print("matchFingerprint size: \(matchFingerprint.pointee.dataSize)")
            let tempPointer = matchFingerprint.pointee.data!
            var tempString = "["
            for tempValueIndex in 0 ..< Int(matchFingerprint.pointee.dataSize) {
                tempString += "\(tempPointer[tempValueIndex])"
                if (tempValueIndex < (matchFingerprint.pointee.dataSize - 1)) {
                    tempString += ","
                } else {
                    tempString += "]"
                }
            }
            print(tempString)
            
            // create the file name
            let recordingFolderURL = Debug.recordingFolderURL
            let format = DateFormatter()
            format.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let filename = "Match-\(format.string(from: Date()))"
            
            // write the fingerprint
            let resultsFileURL = recordingFolderURL.appendingPathComponent(filename + ".txt")
            _ = try? tempString.write(to: resultsFileURL, atomically: true, encoding: .utf8)
            
            // write the tuneurl audio
            let fingerprintFileURL = recordingFolderURL.appendingPathComponent(filename + ".aif")
            _ = try? AudioUtility.writeAudioFile(to: fingerprintFileURL, buffer: matchAudioBuffer, sampleRate: 44100.0)
#endif // DEBUG
            
            // create the match fingerprint data
            var matchFingerprintData = [UInt8]()
            let pointer = matchFingerprint.pointee.data!
            for x in 0 ..< Int(matchFingerprint.pointee.dataSize) {
                matchFingerprintData.append(pointer[x])
            }
            
            // cleanup
            FingerprintFree(matchFingerprint)
            
//// ask the server to match the audio (V2 primary, V1 fallback)
//            Server.shared.matchFingerprint(for: matchFingerprintData, queue: nil) { [weak self] match in
//                guard let self else { return }
//
//                if let match {
//                    match.fingerprintVersion = "V2"
//                    self.matchCallback?(match)
//                    return
//                }

//                // V2 returned no match — fall back to V1 once
//#if DEBUG
//                print("TuneURL: V2 match returned nil, retrying with V1 fingerprint.")
//#endif

                guard let v1Fingerprint = ExtractFingerprint(
                    matchResampledBuffer,
                    Int32(matchResampledBuffer.count),
                    Int32(FORMAT_VERSION_V1)
                ) else {
                    return
                }

                var v1Data = [UInt8]()
                let v1Pointer = v1Fingerprint.pointee.data!
                for x in 0 ..< Int(v1Fingerprint.pointee.dataSize) {
                    v1Data.append(v1Pointer[x])
                }
                FingerprintFree(v1Fingerprint)

                Server.shared.matchFingerprint(for: v1Data, queue: nil) { [weak self] fallbackMatch in
                    guard let self, let fallbackMatch, let matchCallback = self.matchCallback else { return }
                    fallbackMatch.fingerprintVersion = "V1"
                    matchCallback(fallbackMatch)
                }
//            }
        }
    }
    
    // MARK: - Private funcs
    private func privateSetTrigger(_ audioFileURL: URL) {
        // clear any current trigger
        NSLog("TuneURL: privateSetTrigger called with %@", audioFileURL.absoluteString)
        FingerprintFree(triggerFingerprint)
        triggerFingerprint = nil
        FingerprintFree(filteredTriggerFingerprint)
        filteredTriggerFingerprint = nil
        triggerSampleCount = 0
        
        // create the trigger fingerprint
        if let trigger = AudioUtility.generateTriggerFingerprint(for: audioFileURL) {
            let fingerprint = trigger.fingerprint
            triggerFingerprint = fingerprint
            triggerSampleCount = trigger.sampleCount
            
            // Unconditional version log — runs in any build config
            if let data = fingerprint.pointee.data {
                let firstByte = data[0]
                let isV2 = (firstByte == UInt8(FINGERPRINT_MAGIC))
                NSLog("TuneURL: TRIGGER VERSION = %@ (first byte 0x%02X, size %d)",
                      isV2 ? "V2" : "V1",
                      firstByte,
                      fingerprint.pointee.dataSize)
            } else {
                NSLog("TuneURL: TRIGGER fingerprint has nil data pointer")
            }
        } else {
            NSLog("TuneURL: TRIGGER generateFingerprint returned nil")
        }

        // high-passed trigger for the filtered check (no echo copies on the stream)
        if triggerFingerprint != nil, let samples = AudioUtility.loadTriggerSamples(for: audioFileURL),
           let filtered = AudioUtility.makeTriggerReferences(from: samples, echoRooms: []).first {
            filteredTriggerFingerprint = filtered.fingerprint
            Diagnostics.log(String(format: "TuneURL_DIAG: stream trigger loaded: %ld samples, high-pass %.0f Hz, pass >%.2f",
                                   triggerSampleCount, AudioUtility.triggerHighPassCutoff, triggerThreshold))
        } else {
            Diagnostics.log("TuneURL_DIAG: stream filtered trigger could not be built, using the unfiltered check (pass >0.10)")
        }
    }
    
    private func audioConverter(from format: AVAudioFormat) -> AVAudioConverter? {
        if let cachedAudioConverter, cachedAudioConverter.inputFormat == format {
            return cachedAudioConverter
        }
        let converter = AVAudioConverter(from: format, to: bufferFormat)
        cachedAudioConverter = converter
        return converter
    }
    
    private func convertAudioBuffer(_ buffer: AVAudioPCMBuffer, _ converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        // setup the converted audio buffer
        let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: bufferFormat,
            frameCapacity: AVAudioFrameCount(bufferFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate)
        )
        guard let convertedBuffer else { return nil }
        
        // process the buffer with the audio converter
        var error: NSError?
        var newBufferAvailable = true
        converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            if newBufferAvailable {
                outStatus.pointee = .haveData
                newBufferAvailable = false
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }
        
#if DEBUG
        if let error {
            print("Audio Buffer Convertion ERROR: \(error.localizedDescription)")
        }
#endif
        
        if (convertedBuffer.frameLength == 0) {
            return nil
        }
    
        return convertedBuffer
    }
}
