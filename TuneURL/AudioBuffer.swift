//
//  AudioBuffer.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/2/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import AVFoundation
import Foundation


enum AudioBufferError: Error {
	case internalError
}


class AudioBuffer {

	// private
	private let bufferQueue: DispatchQueue

	// memory buffer
	private var memoryBuffer: Data
	private var memoryBufferCurrentOffset = 0
	private var memoryBufferCurrentSize = 0
	private var memoryBufferMaxSize = 0

	// audio configuration
	private let sampleRate: Double
	private let sampleSize = 2	// 16-bit mono audio sample size (in bytes)

	// fingerprint detection
	private var untestedSize = 0

	// MARK: -

	var totalTimeRecorded: Double {
		// calculate the time recorded from the buffer data size
		return (Double(memoryBufferCurrentSize / sampleSize) / sampleRate)
	}

	var untestedTime: Double {
		// calculate the untested duration (in seconds)
		return ((Double(untestedSize) / Double(sampleSize)) / sampleRate)
	}

	// MARK: -

	static func dataSizeForRecordingTime(_ seconds: Double, sampleRate: Double, sampleSize: Int) -> Int
	{
		// calculate the bytes required to save the recording time
		return Int(ceil((seconds * sampleRate) * Double(sampleSize)))
	}

	// MARK: -

	init(captureDuration: Double, sampleRate rate: Double)
	{
		// save the sample rate
		sampleRate = rate

		// setup the audio buffer queue
		bufferQueue = DispatchQueue(label: "com.tuneurl.ios.AudioBuffer")

		// setup the memory buffer
		memoryBufferMaxSize = AudioBuffer.dataSizeForRecordingTime(captureDuration, sampleRate: sampleRate, sampleSize: sampleSize)
		memoryBuffer = Data(count: memoryBufferMaxSize)
	}

	deinit
	{
		stopRecording()
	}

	// MARK: -
	// MARK: Public

	func reset()
	{
		bufferQueue.async {

			// reset the buffer
			self.memoryBufferCurrentOffset = 0
			self.memoryBufferCurrentSize = 0

			// reset fingerprint detection
			self.untestedSize = 0

		}
	}

	func startRecording()
	{
		// reset recording
		self.reset()
	}

	func stopRecording()
	{
	}

	// MARK: -

	func appendSampleBuffer(_ sampleBuffer: AVAudioPCMBuffer)
	{
		// get the sample buffer data length
		let sampleBufferDataLength = (Int(sampleBuffer.frameLength) * sampleSize)
		guard (sampleBufferDataLength != 0) else {
			NSLog("AudioBuffer: Error appending empty sample buffer.")
			return
		}

		bufferQueue.async {

			var sampleBufferOffset = 0
			var copyLength = sampleBufferDataLength

			// check the space left at the end of the memory buffer
			let availableSize = (self.memoryBufferMaxSize - self.memoryBufferCurrentOffset)

			// check if copying will wrap
			if (copyLength > availableSize) {
				// write the first part of a wrapping copy
				if (availableSize > 0) {
					// copy to the end of the memory buffer
					self.copyToMemoryBuffer(from: sampleBuffer, atOffset: sampleBufferOffset, toOffset: self.memoryBufferCurrentOffset, length: availableSize)
					// update the buffer sizes
					self.memoryBufferCurrentSize += availableSize
					self.memoryBufferCurrentSize = min(self.memoryBufferCurrentSize, self.memoryBufferMaxSize)
					self.untestedSize += availableSize
					sampleBufferOffset += availableSize
					copyLength -= availableSize
				}
				// reset the memory buffer offset
				self.memoryBufferCurrentOffset = 0
			}

			// safety check
			guard (copyLength > 0) else {
				NSLog("AudioBuffer: Internal error while copying sample buffer data.")
				return
			}

			// copy the remaining sample buffer data
			self.copyToMemoryBuffer(from: sampleBuffer, atOffset: sampleBufferOffset, toOffset: self.memoryBufferCurrentOffset, length: copyLength)

			// update the memory buffer offset
			self.memoryBufferCurrentOffset += copyLength
			if (self.memoryBufferCurrentOffset >= self.memoryBufferMaxSize) {
				self.memoryBufferCurrentOffset = 0
			}

			// update the buffer size
			self.memoryBufferCurrentSize += copyLength
			self.memoryBufferCurrentSize = min(self.memoryBufferCurrentSize, self.memoryBufferMaxSize)
			self.untestedSize += copyLength
		}
	}

	func copyBufferData(maxDuration: Double) -> [Int16]?
	{
		return bufferQueue.sync {

			// safety check
			guard (maxDuration > 1.0) else {
				NSLog("AudioBuffer: Attempting to create sample buffer that's too short.")
				return nil
			}

			// calculate the data size
			let maxCopyLength = AudioBuffer.dataSizeForRecordingTime(maxDuration, sampleRate: sampleRate, sampleSize: sampleSize)
			var memoryCopyLength = min(memoryBufferCurrentSize, maxCopyLength)

			// check the memory copy length
			guard (memoryCopyLength > 0) else {
				return nil
			}

			// write the data from the memory buffer
			var returnBuffer = [Int16](repeating: 0, count: (memoryCopyLength >> 1))
			var returnBufferOffset = 0

			// calculate the starting offset for the copy
			var copyOffset = (memoryBufferCurrentOffset - memoryCopyLength)
			if (copyOffset < 0) {
				copyOffset += memoryBufferMaxSize
			}

			// start writing to the return buffer
			returnBuffer.withUnsafeMutableBufferPointer {
				returnBufferPointer in

				// copy data from the memory buffer
				while (memoryCopyLength > 0) {
					let availableLength = (memoryBufferMaxSize - copyOffset)
					let currentChunkLength = min(memoryCopyLength, availableLength)

					let destinationSlice = returnBufferPointer[returnBufferOffset...]
					let destinationBufferPointer = UnsafeMutableBufferPointer(rebasing: destinationSlice)

					let sourceRange = (copyOffset ..< (copyOffset + currentChunkLength))
					memoryBuffer.copyBytes(to: destinationBufferPointer, from: sourceRange)

					// update the copy
					returnBufferOffset += (currentChunkLength >> 1)
					memoryCopyLength -= currentChunkLength
					copyOffset += currentChunkLength
					if (copyOffset >= memoryBufferMaxSize) {
						// wrap to the start of the buffer
						copyOffset = 0
					}
				}
			}

			return returnBuffer
		}
	}

	func export(to fileURL: URL, maxDuration: Double, completion: @escaping ((Bool, Double) -> Void))
	{
		bufferQueue.async {

			var recordingDuration = 0.0
			var success = false

			do {
				// write the audio file
				recordingDuration = try self.writeAudioFile(to: fileURL, maxDuration: maxDuration)
				success = true
			} catch {
				// error exporting
			}

			// call the completion handler
			completion(success, recordingDuration)

		}
	}

	func resetUntestedSize()
	{
		untestedSize = 0
	}

	// MARK: -
	// MARK: Private

	private func copyToMemoryBuffer(from sampleBuffer: AVAudioPCMBuffer, atOffset sampleBufferOffset: Int, toOffset memoryOffset: Int, length copyLength: Int)
	{
		if let int16Data = sampleBuffer.int16ChannelData {
			let sourcePointer = int16Data[0].advanced(by: (sampleBufferOffset >> 1))

			// copy the data
			let copyRange = (memoryOffset ..< (memoryOffset + copyLength))
			memoryBuffer.replaceSubrange(copyRange, with: sourcePointer, count: copyLength)
		}
	}

	private func durationForDataSize(_ dataSize: Int) -> Double
	{
		return (Double(dataSize / sampleSize) / sampleRate)
	}

	// MARK: -

	private func writeAudioFile(to fileURL: URL, maxDuration: Double) throws -> Double
	{
		// safety check
		guard (maxDuration > 1.0) else {
			NSLog("AudioBuffer: Attempting to export audio that's too short.")
			throw AudioBufferError.internalError
		}

		// setup the audio file format
		var audioCaptureFileRef: ExtAudioFileRef?
		var streamDescription = AudioStreamBasicDescription(
			mSampleRate: sampleRate,
			mFormatID: kAudioFormatMPEG4AAC,
			mFormatFlags: 0,
			mBytesPerPacket: 0,
			mFramesPerPacket: 1024,
			mBytesPerFrame: 0,
			mChannelsPerFrame: 1,
			mBitsPerChannel: 0,
			mReserved: 0)

		// create the audio capture file
		var result = ExtAudioFileCreateWithURL(fileURL as CFURL, kAudioFileM4AType, &streamDescription, nil, AudioFileFlags.eraseFile.rawValue, &audioCaptureFileRef)
		if (result != noErr) {
			NSLog("AudioBuffer: Error creating audio capture file. (\(result))")
			throw AudioBufferError.internalError
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

		result = ExtAudioFileSetProperty(audioCaptureFileRef!, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.stride), &bufferFormat)
		if (result != noErr) {
			// report the error
			NSLog("AudioBuffer: Error setting audio capture data format. (\(result))")
			error = true
		}

		// calculate the data size
		let maxCopyLength = AudioBuffer.dataSizeForRecordingTime(maxDuration, sampleRate: sampleRate, sampleSize: sampleSize)
		var memoryCopyLength = min(memoryBufferCurrentSize, maxCopyLength)
		let totalDataSize = memoryCopyLength

		// write the data from the memory buffer
		if ((error == false) && (memoryCopyLength > 0)) {

			// calculate the starting offset for the copy
			var copyOffset = (memoryBufferCurrentOffset - memoryCopyLength)
			if (copyOffset < 0) {
				copyOffset += memoryBufferMaxSize
			}

			// copy data from the memory buffer
			while ((error == false) && (memoryCopyLength > 0)) {
				let availableLength = (memoryBufferMaxSize - copyOffset)
				let currentChunkLength = min(memoryCopyLength, availableLength)

				memoryBuffer.withUnsafeMutableBytes {
					bufferPointer in

					// create the buffer list for the memory buffer
					if let basePointer = bufferPointer.baseAddress {
						let offsetPointer = basePointer.advanced(by: copyOffset)
						let frameCount = UInt32(currentChunkLength >> 1)
						var bufferList = AudioBufferList(
							mNumberBuffers: 1,
							mBuffers: CoreAudio.AudioBuffer(
								mNumberChannels: 1,
								mDataByteSize: UInt32(currentChunkLength),
								mData: offsetPointer))

						// write the buffer list to the audio file
						result = ExtAudioFileWrite(audioCaptureFileRef!, frameCount, &bufferList)
						if (result != noErr) {
							NSLog("Error writing to audio capture file. (\(result))")
							error = true
						}
					}
				}

				// update the copy
				memoryCopyLength -= currentChunkLength
				copyOffset += currentChunkLength
				if (copyOffset >= memoryBufferMaxSize) {
					// wrap to the start of the file
					copyOffset = 0
				}
			}
		}

		// close the audio file
		ExtAudioFileDispose(audioCaptureFileRef!)
		audioCaptureFileRef = nil

		if (error) {
			// cleanup on error
			_ = try? FileManager.default.removeItem(at: fileURL)
			// report the error
			NSLog("AudioBuffer: Error writing audio file. (Deleting file.)")
			throw AudioBufferError.internalError
		}

		// return the duration of the audio file written
		return durationForDataSize(totalDataSize)
	}

}
