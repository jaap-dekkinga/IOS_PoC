//
//  AudioUtility.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/12/19.
//  Copyright © 2019-2022 TuneURL Inc. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation
@_implementationOnly import Fingerprint_Private

enum AudioUtilityError: Error {
	case internalError
}

class AudioUtility {

    // MARK: - Resampling
	static func changeSampleRate(sampleRate: Double, buffer1: [Int16]) -> [Int16]? {
		guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100.0, channels: 1, interleaved: false) else {
			NSLog("TuneURL: Error creating audio format for sample rate conversion.")
			return nil
		}

		guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false) else {
			NSLog("TuneURL: Error creating audio format for sample rate conversion.")
			return nil
		}

		guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
			NSLog("TuneURL: Error creating audio converter for sample rate conversion.")
			return nil
		}

		// TODO: don't allocate a buffer every time here...
		// TODO: don't allocte a buffer this large
		let sampleRateConversionRatio: Double = (sampleRate / 44100.0)
		let outputBufferSize = AVAudioFrameCount((Double(buffer1.count) * sampleRateConversionRatio))
		guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputBufferSize) else {
			NSLog("TuneURL: Error creating input audio buffer for sample rate conversion.")
			return nil
		}

		var remainingSamples = buffer1.count
		var currentSampleOffset = 0
		var error: NSError?

		// convert the buffer
		let result = converter.convert(to: outputBuffer, error: &error, withInputFrom: {
			(packetCount, status) -> AVAudioBuffer? in

			// calculate the copy count
			let copySampleCount = min(Int(packetCount), remainingSamples)
			if (copySampleCount == 0) {
				status.pointee = .endOfStream
				return nil
			}

			// create the buffer
			guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(copySampleCount)) else {
				NSLog("TuneURL: Error creating input audio buffer for sample rate conversion.")
				status.pointee = .endOfStream
				return nil
			}

			// TODO: use the original source buffer instead of making a copy here

			buffer1.withUnsafeBytes {
				sourceBufferPointer in

				// create the copy pointers
				let sourcePointer = sourceBufferPointer.baseAddress?.advanced(by: (currentSampleOffset << 1))
				if let int16Data = buffer.int16ChannelData {
					let destinationPointer = int16Data[0]
					// copy the data
					memcpy(destinationPointer, sourcePointer, (copySampleCount << 1))
					currentSampleOffset += copySampleCount
					remainingSamples -= copySampleCount
					buffer.frameLength = AVAudioFrameCount(copySampleCount)
				}
			}

			status.pointee = .haveData
			return buffer
		})

		// check for errors
		if (result == .error) {
			NSLog("TuneURL: Error converting audio sample rate.")
			return nil
		}

		if (error != nil) {
			NSLog("TuneURL: Error converting audio sample rate. (\(error!.localizedDescription))")
			return nil
		}

		// copy the output buffer
		let outputFrames = Int(outputBuffer.frameLength)
		var resultBuffer = [Int16](repeating: 0, count: outputFrames)

		resultBuffer.withUnsafeMutableBytes {
			resultBufferPointer in

			// create the copy pointers
			let destinationPointer = resultBufferPointer.baseAddress
			if let int16Data = outputBuffer.int16ChannelData {
				let sourcePointer = int16Data[0]
				// copy the data
				memcpy(destinationPointer, sourcePointer, (outputFrames << 1))
			}
		}

		return resultBuffer
	}

    // MARK: - Convertion
    static func convertFormat(
        of inputBuffer: AVAudioPCMBuffer,
        to outputFormat: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
		// create the output buffer
		guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: inputBuffer.frameLength) else {
			NSLog("TuneURL: Error creating audio output buffer for format conversion.")
			return nil
		}

		// create the audio converter
		guard let converter = AVAudioConverter(from: inputBuffer.format, to: outputFormat) else {
			NSLog("TuneURL: Error creating audio converter for format conversion.")
			return nil
		}

		// convert the audio
		do {
			try converter.convert(to: outputBuffer, from: inputBuffer)
		} catch {
			NSLog("TuneURL: Error converting audio format.")
			return nil
		}

		return outputBuffer
	}

    static func convertSampleRate(
        of inputBuffer: AVAudioPCMBuffer,
        to sampleRate: Double,
        asFloat: Bool
    ) -> AVAudioPCMBuffer? {
		// get the input format
		let inputFormat = inputBuffer.format
		let inputIsFloat = (inputFormat.commonFormat == .pcmFormatFloat32)
		guard ((inputFormat.channelCount == 1) || (inputFormat.isInterleaved == false)),
			  ((inputFormat.commonFormat == .pcmFormatInt16) || (inputFormat.commonFormat == .pcmFormatFloat32)) else {
			NSLog("TuneURL: Error creating with input audio format for sample rate conversion.")
			return nil
		}

		// create the output format
		guard let outputFormat = AVAudioFormat(commonFormat: (asFloat) ? .pcmFormatFloat32 : .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false) else {
			NSLog("TuneURL: Error creating audio format for sample rate conversion.")
			return nil
		}

		// create the audio converter
		guard let converter = AVAudioConverter(from: inputBuffer.format, to: outputFormat) else {
			NSLog("TuneURL: Error creating audio converter for sample rate conversion.")
			return nil
		}

		// create the output buffer
		let sampleRateConversionRatio = (sampleRate / inputFormat.sampleRate)
		let outputBufferSize = AVAudioFrameCount((Double(inputBuffer.frameLength) * sampleRateConversionRatio))
		guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputBufferSize) else {
			NSLog("TuneURL: Error creating input audio buffer for sample rate conversion.")
			return nil
		}

		var remainingSamples = Int(inputBuffer.frameLength)
		var currentSampleOffset = 0
		var error: NSError?

		// convert the buffer
        let result = converter.convert(
            to: outputBuffer,
            error: &error,
            withInputFrom: { (packetCount, status) -> AVAudioBuffer? in

			// calculate the copy count
			let copySampleCount = min(Int(packetCount), remainingSamples)
			if (copySampleCount == 0) {
				status.pointee = .endOfStream
				return nil
			}

			// create the copied buffer
			guard let copyBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(copySampleCount)) else {
				NSLog("TuneURL: Error creating input audio buffer for sample rate conversion.")
				status.pointee = .endOfStream
				return nil
			}

			// TODO: use the original source buffer instead of making a copy here

			if (inputIsFloat) {
				// get the input buffer data
				guard let inputBufferData = inputBuffer.floatChannelData?.pointee,
					  let copyBufferData = copyBuffer.floatChannelData?.pointee else {
					NSLog("TuneURL: Error getting buffer data for sample rate conversion.")
					status.pointee = .endOfStream
					return nil
				}
				// copy the data
				let sourcePointer = inputBufferData.advanced(by: currentSampleOffset)
				memcpy(copyBufferData, sourcePointer, (copySampleCount << 2))
			} else {
				// get the input buffer data
				guard let inputBufferData = inputBuffer.int16ChannelData?.pointee,
					  let copyBufferData = copyBuffer.int16ChannelData?.pointee else {
					NSLog("TuneURL: Error getting buffer data for sample rate conversion.")
					status.pointee = .endOfStream
					return nil
				}

				// copy the data
				let sourcePointer = inputBufferData.advanced(by: currentSampleOffset)
				memcpy(copyBufferData, sourcePointer, (copySampleCount << 1))
			}

			currentSampleOffset += copySampleCount
			remainingSamples -= copySampleCount
			copyBuffer.frameLength = AVAudioFrameCount(copySampleCount)
			status.pointee = .haveData

			return copyBuffer
		})

		// check for errors
		if (result == .error) {
			NSLog("TuneURL: Error converting audio sample rate.")
			return nil
		}

		if (error != nil) {
			NSLog("TuneURL: Error converting audio sample rate. (\(error!.localizedDescription))")
			return nil
		}

		return outputBuffer
	}

    // MARK: - Fingerprints
	static func generateFingerprint(for fileURL: URL) -> UnsafeMutablePointer<Fingerprint>? {
		// prepare the audio file buffer
		guard let audioFileBuffer = AudioUtility.prepareAudioForProcessing(fileURL, asFloat: false) else {
			NSLog("TuneURL: Error preparing audio file buffer for processing.")
			return nil
		}

		// extract the fingerprint
		guard let bufferData = audioFileBuffer.int16ChannelData?.pointee,
    		let fingerprint = ExtractFingerprint(bufferData, Int32(audioFileBuffer.frameLength), Int32(FORMAT_VERSION_V2)) else {
				NSLog("TuneURL: Error extracting fingerprint from audio file.")
			return nil
		}

		return fingerprint
	}

    // MARK: - Buffers
	static func prepareAudioForProcessing(_ fileURL: URL, asFloat: Bool) -> AVAudioPCMBuffer? {
		do {
			// open the audio file
			let audioFile = try AVAudioFile(forReading: fileURL)
			var audioFileFormat = audioFile.processingFormat

			// allocate the audio buffer
			guard var audioFileBuffer = AVAudioPCMBuffer(pcmFormat: audioFileFormat, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
				NSLog("TuneURL: Error allocating audio file buffer.")
				return nil
			}

			// read the audio into the audio buffer
			try audioFile.read(into: audioFileBuffer)

			// convert the audio to the processing format
			if (audioFileFormat.channelCount > 1) {
				guard let convertedFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audioFileFormat.sampleRate, channels: 1, interleaved: false),
					  let convertedBuffer = AudioUtility.convertFormat(of: audioFileBuffer, to: convertedFormat) else {
					NSLog("TuneURL: Error converting audio buffer for processing.")
					return nil
				}
				audioFileBuffer = convertedBuffer
				audioFileFormat = convertedFormat
			}

			// resample the audio (if necessary)
			if (audioFileFormat.sampleRate != FINGERPRINT_SAMPLE_RATE) {
				guard let resampledBuffer = AudioUtility.convertSampleRate(of: audioFileBuffer, to: FINGERPRINT_SAMPLE_RATE, asFloat: asFloat) else {
					return nil
				}
				return resampledBuffer
			}

			return audioFileBuffer
		} catch {
			NSLog("TuneURL: Error reading audio file. (\(error.localizedDescription))")
			return nil
		}
	}

    static func writeAudioBuffer(_ audioBuffer: AVAudioPCMBuffer, to fileURL: URL) -> Bool {
		// Note: The audio buffer format must be .pcmFormatFloat32.
		do {
			// write the audio file
			let settings: [String : Any] = [
				AVFormatIDKey: kAudioFormatLinearPCM,
				AVSampleRateKey: audioBuffer.format.sampleRate,
				AVNumberOfChannelsKey: audioBuffer.format.channelCount
			]
			let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
			try audioFile.write(from: audioBuffer)
			return true
		} catch {
			NSLog("TuneURL: Error writing audio file. (\(error.localizedDescription))")
			return false
		}
	}

	static func writeAudioFile(to fileURL: URL, buffer: [Int16], sampleRate: Double) throws {
		// safety check
		guard (buffer.count > 0) else {
			NSLog("TuneURL: Attempting to write audio file with audio that's too short.")
			throw AudioUtilityError.internalError
		}

		// setup the audio file format
		var audioFileRef: ExtAudioFileRef?
		var streamDescription = AudioStreamBasicDescription(
			mSampleRate: sampleRate,
			mFormatID: kAudioFormatLinearPCM,
			mFormatFlags: (kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian),
			mBytesPerPacket: 2,
			mFramesPerPacket: 1,
			mBytesPerFrame: 2,
			mChannelsPerFrame: 1,
			mBitsPerChannel: 16,
			mReserved: 0)

		// create the audio capture file
		var result = ExtAudioFileCreateWithURL(fileURL as CFURL, kAudioFileAIFFType, &streamDescription, nil, AudioFileFlags.eraseFile.rawValue, &audioFileRef)
		if (result != noErr) {
			NSLog("TuneURL: Error creating audio capture file. (\(result))")
			throw AudioUtilityError.internalError
		}

		// setup the input buffer format
		var error = false
		var bufferFormat = AudioStreamBasicDescription(
			mSampleRate: sampleRate,
			mFormatID: kAudioFormatLinearPCM,
			mFormatFlags: (kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger),
			mBytesPerPacket: 2,
			mFramesPerPacket: 1,
			mBytesPerFrame: 2,
			mChannelsPerFrame: 1,
			mBitsPerChannel: 16,
			mReserved: 0)

		result = ExtAudioFileSetProperty(audioFileRef!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.stride), &bufferFormat)
		if (result != noErr) {
			// report the error
			NSLog("TuneURL: Error setting audio capture data format. (\(result))")
			error = true
		}

		// write the buffer
		var mutableBuffer = buffer
		mutableBuffer.withUnsafeMutableBytes {
			bufferPointer in

			// create the buffer list for the memory buffer
			if let basePointer = bufferPointer.baseAddress {
				let frameCount = UInt32(buffer.count)
				var bufferList = AudioBufferList(
					mNumberBuffers: 1,
					mBuffers: CoreAudio.AudioBuffer(
						mNumberChannels: 1,
						mDataByteSize: UInt32(buffer.count << 1),
						mData: basePointer))

				// write the buffer list to the audio file
				result = ExtAudioFileWrite(audioFileRef!, frameCount, &bufferList)
				if (result != noErr) {
					NSLog("TuneURL: Error writing to audio capture file. (\(result))")
					error = true
				}
			}
		}

		// close the audio file
		ExtAudioFileDispose(audioFileRef!)
		audioFileRef = nil

		if (error) {
			// cleanup on error
			_ = try? FileManager.default.removeItem(at: fileURL)
			// report the error
			NSLog("TuneURL: Error writing audio file. (Deleting file.)")
			throw AudioUtilityError.internalError
		}
	}
}
