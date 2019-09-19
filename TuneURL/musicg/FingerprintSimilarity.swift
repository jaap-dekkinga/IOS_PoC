//
//  FingerprintSimilarity.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class FingerprintSimilarity {

	// From FingerprintProperties
	// in order to have 5fps with 2048 sampleSizePerFrame, wave's sample rate need to be 10240 (sampleSizePerFrame*fps)
	private let fps = 5
	// number of points in each frame, i.e. top 4 intensities in fingerprint
	private let numRobustPointsPerFrame = 4
	// ----

//	private FingerprintProperties fingerprintProperties = FingerprintProperties.getInstance();
	private var mostSimilarFramePosition = Int.min
	private var score: Float = -1.0
	private var similarity: Float = -1.0

	func getMostSimilarFramePosition() -> Int
	{
		return mostSimilarFramePosition
	}

	func setMostSimilarFramePosition(_ mostSimilarFramePosition: Int)
	{
		self.mostSimilarFramePosition = mostSimilarFramePosition
	}

	/**
	* Get the similarity of the fingerprints
	* similarity from 0~1, which 0 means no similar feature is found and 1 means in average there is at least one match in every frame
	*
	* @return fingerprints similarity
	*/

	func getSimilarity() -> Float
	{
		return similarity
	}

	/**
	* Set the similarity of the fingerprints
	*
	* @param fingerprints similarity
	*/

	func setSimilarity(_ similarity: Float)
	{
		self.similarity = similarity
	}

	/**
	* Get the similarity score of the fingerprints
	* Number of features found in the fingerprints per frame
	*
	* @return fingerprints similarity score
	*/

	func getScore() -> Float
	{
		return score
	}

	/**
	* Set the similarity score of the fingerprints
	*
	* @param score
	*/

	func setScore(_ score: Float)
	{
		self.score = score
	}

	/**
	* Get the most similar position in terms of time in second
	*
	* @return most similar starting time
	*/

	func getsetMostSimilarTimePosition() -> Float
	{
		return (Float(mostSimilarFramePosition) / Float(numRobustPointsPerFrame) / Float(fps))
	}

}
