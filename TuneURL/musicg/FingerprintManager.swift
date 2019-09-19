//
//  FingerprintManager.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/9/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


var TEMPindex = 0


class FingerprintManager {

	// From FingerPrintProperties
	let sampleRate: Float = (2048.0 * 5.0)
	let numFilterBanks = 4
	// ----

	func extractFingerprint(_ wave: [Int16], resample: Bool) -> [UInt8]?
	{
//		int[][] coordinates;	// coordinates[x][0..3]=y0..y3
//		byte[] fingerprint=new byte[0];
/*
		// resample to target rate
		Resampler resampler=new Resampler();
		int sourceRate = wave.getWaveHeader().getSampleRate();
		int targetRate = fingerprintProperties.getSampleRate();

		byte[] resampledWaveData=resampler.reSample(wave.getBytes(), wave.getWaveHeader().getBitsPerSample(), sourceRate, targetRate);

		// update the wave header
		WaveHeader resampledWaveHeader=wave.getWaveHeader();
		resampledWaveHeader.setSampleRate(targetRate);

		// make resampled wave
		Wave resampledWave=new Wave(resampledWaveHeader,resampledWaveData);
		// end resample to target rate
*/

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
		let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

		let fileURL1 = documentsDirectory.appendingPathComponent("source-\(TEMPindex).wav")
		_ = try? AudioUtility.writeAudioFile(to: fileURL1, buffer: wave, sampleRate: 44100.0)

		let fileURL = documentsDirectory.appendingPathComponent("resampled-\(TEMPindex).wav")
		_ = try? AudioUtility.writeAudioFile(to: fileURL, buffer: resampledWave, sampleRate: Double(sampleRate))

		TEMPindex += 1
*/
// ----


		// from FingerprintProperties
		// number of points in each frame, i.e. top 4 intensities in fingerprint
		let numRobustPointsPerFrame = 4

		// overlapFactor: 8 means each move 1/8 nSample length. 1 means no overlap, better 1,2,4,8 ...	32
		let overlapFactor = 4
		// sampleSizePerFrame: number of audio samples in a frame, it is suggested to be the FFT Size
		let sampleSizePerFrame = 2048
		// ----

		// get spectrogram's data
//		Spectrogram spectrogram=resampledWave.getSpectrogram(sampleSizePerFrame, overlapFactor)
		let spectrogram = Spectrogram(wave: resampledWave, fftSampleSize: sampleSizePerFrame, overlapFactor: overlapFactor)
		let spectrogramData = spectrogram.getNormalizedSpectrogramData()

//		List<Integer>[] pointsLists = getRobustPointList(spectrogramData)
		var pointsLists = getRobustPointList(spectrogramData)
		let numFrames = pointsLists.count

		// prepare fingerprint bytes
//		var coordinates = new int[numFrames][numRobustPointsPerFrame]
		var coordinates = [[Int]](repeating: [Int](repeating: 0, count: numRobustPointsPerFrame), count: numFrames)

		for x in 0 ..< numFrames {
			if (pointsLists[x].count == numRobustPointsPerFrame) {
//				Iterator<Integer> pointsListsIterator=pointsLists[x].iterator();
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
		// end make fingerprint

		// for each valid coordinate, append with its intensity
//		List<Byte> byteList=new LinkedList<Byte>();
		var byteList = [UInt8]()

		for i in 0 ..< numFrames {
			for j in 0 ..< numRobustPointsPerFrame {
				if (coordinates[i][j] != -1) {
					// first 2 bytes is x
					let x = i
					byteList.append(UInt8((x >> 8) & 0xFF))
					byteList.append(UInt8(x & 0xFF))

					// next 2 bytes is y
					let y = coordinates[i][j]
					byteList.append(UInt8((y >> 8) & 0xFF))
					byteList.append(UInt8(y & 0xFF))

					// next 4 bytes is intensity
					let intMax = Double(0x7FFFFFFF)
//					let intMax = Double(UInt32.max)
					let intensityFloat = spectrogramData[x][y]
					let intensityDouble = (Double(intensityFloat) * intMax)
					let intensity = Int(intensityDouble)
//					let intensity = Int(intensityFloat * Float(UInt32.max))
					// spectrogramData is ranged from 0~1
					byteList.append(UInt8((intensity >> 24) & 0xFF))
					byteList.append(UInt8((intensity >> 16) & 0xFF))
					byteList.append(UInt8((intensity >> 8) & 0xFF))
					byteList.append(UInt8(intensity & 0xFF))
				}
			}
		}
		// end for each valid coordinate, append with its intensity

		// TODO: finish below...

		return byteList
/*
		fingerprint = new byte[byteList.count]
		Iterator<Byte> byteListIterator=byteList.iterator();
		int pointer = 0;
		while(byteListIterator.hasNext()) {
			fingerprint[pointer++] = byteListIterator.next();
		}

		return fingerprint;
*/	}


	// robustLists[x]=y1,y2,y3,...
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
//			let processorChain = TopManyPointsProcessorChain(bankIntensities, 1)
//			var processedIntensities = processorChain.getIntensities()
			let processor = RobustIntensityProcessor(intensities: bankIntensities, numPointsPerFrame: 1)
			processor.execute()
			let processedIntensities = processor.getIntensities()

			for i in 0 ..< numX {
				for j in 0 ..< bandwidthPerBank {
					allBanksIntensities[i][j + b * bandwidthPerBank] = processedIntensities[i][j]
				}
			}
		}

//		List<int[]> robustPointList = new LinkedList<int[]>()
		var robustPointList = [ArrayCoord]()

		// find robust points
		for i in 0 ..< allBanksIntensities.count {
			for j in 0 ..< allBanksIntensities[i].count {
				if (allBanksIntensities[i][j] > 0.0) {

//					int[] point = new int[]{i,j}
					//System.out.println(i+","+frequency)
//					robustPointList.add(point)
					robustPointList.append(ArrayCoord(x: i, y: j))
				}
			}
		}
		// end find robust points

//		List<Integer>[] robustLists = new LinkedList[spectrogramData.count]
//		for i in 0 ..< robustLists.count {
//			robustLists[i] = new LinkedList<Integer>()
//		}
		var robustLists = [[Int]](repeating: [Int](), count: spectrogramData.count)

		// robustLists[x]=y1,y2,y3,...
//		Iterator<int[]> robustPointListIterator=robustPointList.iterator();
		for coord in robustPointList {
//		while (robustPointListIterator.hasNext()) {
//			int[] coor=robustPointListIterator.next()
//			robustLists[coor[0]].append(coor[1])
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

		// get the last x-coordinate (length-8&length-7)bytes from fingerprint
		let numFrames = ((Int(fingerprint[fingerprint.count - 8] & 0xFF) << 8) | Int(fingerprint[fingerprint.count - 7] & 0xFF)) + 1
		return numFrames
	}

}
