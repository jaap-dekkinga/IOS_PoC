//
//  AudioUtility.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/12/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import AudioToolbox
import AVFoundation
import Foundation


enum AudioUtilityError: Error {
	case internalError
}


class AudioUtility {

	static func changeSampleRate(sampleRate: Double, buffer1: [Int16]) -> [Int16]?
	{
		guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100.0, channels: 1, interleaved: false) else {
			print("AudioUtility: Error creating audio format.")
			return nil
		}

		guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: false) else {
			print("AudioUtility: Error creating audio format.")
			return nil
		}

		guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
			print("AudioUtility: Error creating audio converter.")
			return nil
		}

		// TODO: don't allocate a buffer every time here...
		// TODO: don't allocte a buffer this large
		let sampleRateConversionRatio: Double = (sampleRate / 44100.0)
		let outputBufferSize = AVAudioFrameCount((Double(buffer1.count) * sampleRateConversionRatio))
		guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputBufferSize) else {
			print("AudioUtility: Error creating input audio buffer.")
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
				print("AudioUtility: Error creating input audio buffer.")
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
			print("AudioUtility: Error converting audio sample rate.")
			return nil
		}

		if (error != nil) {
			print("AudioUtility: Error converting audio sample rate. (\(error!.localizedDescription))")
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

	static func writeAudioFile(to fileURL: URL, buffer: [Int16], sampleRate: Double) throws
	{
		// safety check
		guard (buffer.count > 0) else {
			NSLog("AudioUtility: Attempting to write audio file with audio that's too short.")
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
			NSLog("AudioUtility: Error creating audio capture file. (\(result))")
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
			NSLog("AudioUtility: Error setting audio capture data format. (\(result))")
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
					NSLog("Error writing to audio capture file. (\(result))")
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
			NSLog("AudioUtility: Error writing audio file. (Deleting file.)")
			throw AudioUtilityError.internalError
		}
	}

}
