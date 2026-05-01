//
//  main.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//


import AVFoundation
import Foundation


fileprivate func extractFingerprint(audioData: [Int16]) -> [UInt8]?
{
	// generate the fingerprint
	guard let fingerprint = ExtractFingerprint(audioData, Int32(audioData.count), Int32(FORMAT_VERSION_V1)) else {
		return nil
	}

	var array = [UInt8]()
	let pointer = fingerprint.pointee.data!
	for x in 0 ..< Int(fingerprint.pointee.dataSize) {
		array.append(pointer[x])
	}

	// cleanup
	FingerprintFree(fingerprint)

	return array
}

fileprivate func loadAudio(from fileURL: URL, resample: Bool) -> [Int16]?
{
	var result: OSStatus = noErr
	var audioFile: AudioFileID?
	var propertyDataSize: UInt32 = 8
	var dataSize: UInt64 = 0

	result = AudioFileOpenURL(fileURL as CFURL, .readPermission, kAudioFileAIFFType, &audioFile)
	if (result != noErr) {
		print("Error opening audio file. (\(result))")
		return nil
	}

	result = AudioFileGetProperty(audioFile!, kAudioFilePropertyAudioDataByteCount, &propertyDataSize, &dataSize)
	if (result != noErr) {
		print("Error getting audio file property. (\(result))")
		return nil
	}

	let frameCount = UInt32(dataSize >> 1)	// 16-bit audio
	var dataBuffer = [Int16](repeating: 0, count: Int(frameCount))
	dataBuffer.withUnsafeMutableBytes {
		bufferPointer in

		var packetCount = frameCount
		var dataRead = UInt32(dataSize)

		result = AudioFileReadPacketData(audioFile!, false, &dataRead, nil, 0, &packetCount, bufferPointer.baseAddress)
	}

	// check the result of the read
	if (result != noErr) {
		print("Error reading audio file packet data. (\(result))")
		return nil
	}

	result = AudioFileClose(audioFile!)
	if (result != noErr) {
		print("Error closing audio file. (\(result))")
	}

	return dataBuffer
}

fileprivate func compareFiles(file1: String, file2: String, emitVersion: Int32)
{
	// extract the fingerprints from the audio files
	guard let audioData1 = loadAudio(from: URL(fileURLWithPath: file1), resample: false),
		  let fingerprint1 = ExtractFingerprint(audioData1, Int32(audioData1.count), emitVersion) else {
		print("Error loading audio file. ('\(file1)')")
		return
	}

	guard let audioData2 = loadAudio(from: URL(fileURLWithPath: file2), resample: false),
		  let fingerprint2 = ExtractFingerprint(audioData2, Int32(audioData2.count), emitVersion) else {
		print("Error loading audio file. ('\(file2)')")
		return
	}

	// compare the fingerprints
	let results = CompareFingerprints(fingerprint1, fingerprint2)
	print("mostSimilarFramePosition: \(results.mostSimilarFramePosition)")
	print("mostSimilarStartTime: \(results.mostSimilarStartTime)")
	print("score: \(results.score)")
	print("similarity: \(results.similarity)")

	// cleanup
	FingerprintFree(fingerprint1)
	FingerprintFree(fingerprint2)
}

// MARK: -
let arguments = CommandLine.arguments
let emitVersion: Int32 = arguments.contains("v2") ? Int32(FORMAT_VERSION_V2) : Int32(FORMAT_VERSION_V1)
print("Emit version: \(emitVersion == Int32(FORMAT_VERSION_V2) ? "v2" : "v1")")
var index = 0

while index < arguments.count {

	if (arguments[index].lowercased() == "fingerprint") {
		if ((index + 2) <= arguments.count) {
			let filePath = arguments[index + 1]
			print("Extracting fingerprint: '\(filePath)'")

			// load the audio file
			if let audioData = loadAudio(from: URL(fileURLWithPath: filePath), resample: false) {
				if let fingerprint = extractFingerprint(audioData: audioData) {
					print("Fingerprint:\n\(fingerprint)")
				} else {
					print("Error creating fingerprint.")
				}
			} else {
				print("Error loading audio file. ('\(filePath)')")
			}
		}
		index += 1
	} else if (arguments[index].lowercased() == "compare") {
		if ((index + 3) <= arguments.count) {
			let filePath1 = arguments[index + 1]
			let filePath2 = arguments[index + 2]
			// compare the files
			print("Comparing fingerprints: '\(filePath1)' to '\(filePath2)'")
			compareFiles(file1: filePath1, file2: filePath2)
		}
		index += 2
	}

	index += 1
}
