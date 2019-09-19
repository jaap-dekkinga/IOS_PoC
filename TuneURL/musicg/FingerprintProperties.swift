//
//  FingerprintProperties.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/19/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class FingerprintProperties {

	// the number of points in each frame (i.e. top 4 intensities in fingerprint)
	static let numRobustPointsPerFrame = 4

	// the number of audio samples in a frame (it is suggested to be the FFT Size)
	static let sampleSizePerFrame = 2048

	// overlapFactor: 8 means each move 1/8 nSample length. 1 means no overlap, better 1, 2, 4, 8 ... 32
	static let overlapFactor = 4

	static let numFilterBanks = 4

	// low pass
	static let upperBoundedFrequency = 1500

	// high pass
	static let lowerBoundedFrequency = 400

	// in order to have 5fps with 2048 sampleSizePerFrame, wave's sample rate need to be 10240 (sampleSizePerFrame * fps)
	static let fps = 5

	// the audio's sample rate needed to resample to this in order to fit the sampleSizePerFrame and fps
	static let sampleRate = Float(sampleSizePerFrame * fps)

	// max active pairs per anchor point for reference songs
	static let refMaxActivePairs = 1

	// max active pairs per anchor point for sample clip
	static let sampleMaxActivePairs = 10

	static let numAnchorPointsPerInterval = 10

	// in frames (5fps, 4 overlap per second)
	static let anchorPointsIntervalLength = 4

	// in frame (5fps, 4 overlap per second)
	static let maxTargetZoneDistance = 4

	// num frequency units
	static let numFrequencyUnits = (upperBoundedFrequency - lowerBoundedFrequency + 1) / fps + 1

}
