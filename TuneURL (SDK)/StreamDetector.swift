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
    private let triggerWindowDuration = 4.0

    // Trigger search: the trigger is slid across the window in steps of
    // triggerSlideHop seconds (see AudioUtility.slideTrigger).
    private let triggerSlideHop = 0.125
    // Pass mark. Scores come in steps of 0.04, so "> 0.1" accepts 0.12 and up.
    private let triggerThreshold: Float = 0.1
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
    }

    private func checkForTriggerSound() {
        isCheckPending = false
        audioBuffer.resetUntestedSize()

        // one trigger is visible on several consecutive checks
        if isConfirmingTrigger || Date().timeIntervalSince(lastTriggerTime) < triggerCooldown {
            return
        }

        guard let firstLook = searchForTrigger(label: ""), firstLook.similarity > triggerThreshold else {
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

        guard let match = AudioUtility.slideTrigger(
            over: resampledData,
            triggerFingerprint: triggerFingerprint,
            triggerSampleCount: triggerSampleCount,
            hopSeconds: triggerSlideHop
        ) else {
            return nil
        }

        // Diagnostic — visible in Release builds
        NSLog("TuneURL_DIAG: local v2 similarity=%.4f triggerStart=%.2fs window=%.2fs positions=%ld%@",
              match.similarity, match.startTime, windowSeconds, match.positionsChecked, label)

        let secondsAgo = windowSeconds - Double(match.startTime)
        return TriggerLook(similarity: match.similarity, triggerStart: now.addingTimeInterval(-secondsAgo))
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
