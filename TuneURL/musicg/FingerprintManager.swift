//
//  FingerprintManager.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/9/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class FingerprintManager {

	// private
	private let numFilterBanks = FingerprintProperties.numFilterBanks
	private let sampleRate = FingerprintProperties.sampleRate

	// MARK: -

	func extractFingerprint(_ wave: [Int16], resample: Bool) -> [UInt8]?
	{
		// resample the wave
		let resampledWave: [Int16]

		if (resample) {
			guard let resampled = AudioUtility.changeSampleRate(sampleRate: Double(sampleRate), buffer1: wave) else {
				return nil
			}
			resampledWave = resampled
		} else {
			resampledWave = wave
		}

// TEMP: dump the resampled file
/*
		// create the recording file url
		let recordingFolderURL = AppDelegate.recordingFolderURL

		let fileURL1 = recordingFolderURL.appendingPathComponent("source-\(TEMPindex).wav")
		_ = try? AudioUtility.writeAudioFile(to: fileURL1, buffer: wave, sampleRate: 44100.0)

		let fileURL = recordingFolderURL.appendingPathComponent("resampled-\(TEMPindex).wav")
		_ = try? AudioUtility.writeAudioFile(to: fileURL, buffer: resampledWave, sampleRate: Double(sampleRate))

		TEMPindex += 1
*/
// ----

		let numRobustPointsPerFrame = FingerprintProperties.numRobustPointsPerFrame
		let overlapFactor = FingerprintProperties.overlapFactor
		let sampleSizePerFrame = FingerprintProperties.sampleSizePerFrame

		// get the spectrogram data
		let spectrogram = Spectrogram(wave: resampledWave, fftSampleSize: sampleSizePerFrame, overlapFactor: overlapFactor)
		let spectrogramData = spectrogram.getNormalizedSpectrogramData()

		// get the robust point list
        let pointsLists = getRobustPointList(spectrogramData)
		let numFrames = pointsLists.count

		// prepare fingerprint bytes
//		var coordinates = new int[numFrames][numRobustPointsPerFrame]
		var coordinates = [[Int]](repeating: [Int](repeating: 0, count: numRobustPointsPerFrame), count: numFrames)

		for x in 0 ..< numFrames {
			if (pointsLists[x].count == numRobustPointsPerFrame) {
//				Iterator<Integer> pointsListsIterator=pointsLists[x].iterator()
				for y in 0 ..< numRobustPointsPerFrame {
//					coordinates[x][y] = pointsListsIterator.next()
					coordinates[x][y] = pointsLists[x][y]
				}
			} else {
				// use -1 to fill the empty byte
				for y in 0 ..< numRobustPointsPerFrame {
					coordinates[x][y] = -1
				}
			}
		}

		// build the fingerprint data
		var fingerprintData = [UInt8]()

		for i in 0 ..< numFrames {
			for j in 0 ..< numRobustPointsPerFrame {
				if (coordinates[i][j] != -1) {
					// x-coordinate (2 byte integer)
					let x = i
					fingerprintData.append(UInt8((x >> 8) & 0xFF))
					fingerprintData.append(UInt8(x & 0xFF))

					// y-coordinate (2 byte integer)
					let y = coordinates[i][j]
					fingerprintData.append(UInt8((y >> 8) & 0xFF))
					fingerprintData.append(UInt8(y & 0xFF))

					// intensity (4 byte integer)
					let integerMax = Double(0x7FFFFFFF)
					let intensityFloat = spectrogramData[x][y]
					let intensityDouble = (Double(intensityFloat) * integerMax)
					let intensity = Int(intensityDouble)
					fingerprintData.append(UInt8((intensity >> 24) & 0xFF))
					fingerprintData.append(UInt8((intensity >> 16) & 0xFF))
					fingerprintData.append(UInt8((intensity >> 8) & 0xFF))
					fingerprintData.append(UInt8(intensity & 0xFF))
				}
			}
		}

		return fingerprintData
	}

	// MARK: -
	// MARK: Private

	// robustLists[x] = y1, y2, y3, ...
	private func getRobustPointList(_ spectrogramData: [[Float]]) -> [[Int]]
	{
		let numX = spectrogramData.count
		let numY = spectrogramData[0].count

		var allBanksIntensities = [[Float]](repeating: [Float](repeating: 0.0, count: numY), count: numX)
		let bandwidthPerBank = (numY / numFilterBanks)

		for b in 0 ..< numFilterBanks {

			var bankIntensities = [[Float]](repeating: [Float](repeating: 0.0, count: bandwidthPerBank), count: numX)

			for i in 0 ..< numX {
				for j in 0 ..< bandwidthPerBank {
					bankIntensities[i][j] = spectrogramData[i][j + b * bandwidthPerBank]
				}
			}

			// get the most robust point in each filter bank
			let processor = RobustIntensityProcessor(intensities: bankIntensities, numPointsPerFrame: 1)
			processor.execute()
			let processedIntensities = processor.getIntensities()

			for i in 0 ..< numX {
				for j in 0 ..< bandwidthPerBank {
					allBanksIntensities[i][j + b * bandwidthPerBank] = processedIntensities[i][j]
				}
			}
		}

		var robustPointList = [ArrayCoord]()

		// find robust points
		for i in 0 ..< allBanksIntensities.count {
			for j in 0 ..< allBanksIntensities[i].count {
				if (allBanksIntensities[i][j] > 0.0) {
					robustPointList.append(ArrayCoord(x: i, y: j))
				}
			}
		}

		// robustLists[x] = y1, y2, y3, ...
		var robustLists = [[Int]](repeating: [Int](), count: spectrogramData.count)
		for coord in robustPointList {
			robustLists[coord.x].append(coord.y)
		}

		// return the list per frame
		return robustLists
	}

	// MARK: -

	static func getNumFrames(fingerprint: [UInt8]) -> Int
	{
		if (fingerprint.count < 8) {
			return 0
		}

		// get the last x-coordinate (length - 8 & length - 7) bytes from fingerprint
		let numFrames = ((Int(fingerprint[fingerprint.count - 8] & 0xFF) << 8) | Int(fingerprint[fingerprint.count - 7] & 0xFF)) + 1
		return numFrames
	}

}
