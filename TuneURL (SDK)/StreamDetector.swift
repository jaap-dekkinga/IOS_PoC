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
    private let triggerWindowDuration = 4.0
    
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
            if self.audioBuffer.untestedTime > 5.0 {
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
    private func checkForTriggerSound() {
        audioBuffer.resetUntestedSize()

        // copy the sound data from the buffer
        guard let bufferData = audioBuffer.copyBufferData(maxDuration: triggerWindowDuration) else {
            return
        }

        // resample the fingerprint
        let sampleRate = FINGERPRINT_SAMPLE_RATE
        guard let resampledData = AudioUtility.changeSampleRate(sampleRate: sampleRate, buffer1: bufferData) else {
            return
        }
        
        // generate a fingerprint
        guard let bufferFingerprint = ExtractFingerprint(resampledData, Int32(resampledData.count), Int32(FORMAT_VERSION_V2)) else {
            return
        }

        let matchResults = CompareFingerprints(bufferFingerprint, triggerFingerprint)
        FingerprintFree(bufferFingerprint)
        
        // Diagnostic — visible in Release builds, remove after measurement
        NSLog("TuneURL_DIAG: local v2 similarity=%.4f score=%d mostSimilarStartTime=%.3f",
              matchResults.similarity, matchResults.score, matchResults.mostSimilarStartTime)
        
        // check the match results
        if (matchResults.similarity > 0.1) {
            
            // TODO: Should check if this detection was already caught
            // by the overlapping window.
            
            // calculate the time of the sound relative to now
            let mostSimilarStartingTime = matchResults.mostSimilarStartTime
            let relativeTime = (Float(triggerWindowDuration) - mostSimilarStartingTime)
            
#if DEBUG
            // dump the trigger match results
            print("TuneURL: Trigger detected \(relativeTime) seconds ago. (similarity: \(matchResults.similarity))")
            print("\tTrigger fingerprint score: \(matchResults.score)")
            print("\tTrigger fingerprint similarity: \(matchResults.similarity)")
            print("\tTrigger fingerprint similar time: \(matchResults.mostSimilarStartTime)")
            print("\tTrigger fingerprint most similar frame: \(matchResults.mostSimilarFramePosition)")
#endif // DEBUG
            
            // match the tuneurl
           recognizedTrigger(timeRelativeToNow: relativeTime)
        } else {
#if DEBUG
            print("TuneURL: Trigger not detected. (similarity: \(matchResults.similarity))")
#endif // DEBUG
        }
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
            
// ask the server to match the audio (V2 primary, V1 fallback)
            Server.shared.matchFingerprint(for: matchFingerprintData, queue: nil) { [weak self] match in
                guard let self else { return }

                if let match {
                    match.fingerprintVersion = "V2"
                    self.matchCallback?(match)
                    return
                }

                // V2 returned no match — fall back to V1 once
#if DEBUG
                print("TuneURL: V2 match returned nil, retrying with V1 fingerprint.")
#endif

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
            }
        }
    }
    
    // MARK: - Private funcs
    private func privateSetTrigger(_ audioFileURL: URL) {
        // clear any current trigger
        NSLog("TuneURL: privateSetTrigger called with %@", audioFileURL.absoluteString)
        FingerprintFree(triggerFingerprint)
        triggerFingerprint = nil
        
        // create the trigger fingerprint
        if let fingerprint = AudioUtility.generateFingerprint(for: audioFileURL) {
            triggerFingerprint = fingerprint
            
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
