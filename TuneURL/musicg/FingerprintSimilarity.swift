//
//  FingerprintSimilarity.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class FingerprintSimilarity {

	// the frame number that was most similar
	var mostSimilarFramePosition = Int.min

	// the number of features matched per frame.
	var score: Float = -1.0

	// similarity ranges from 0.0 - 1.0, where 0.0 means no similar features were found
	// and 1.0 means on average there is at least one match in every frame.
	var similarity: Float = -1.0

	// computed
	var mostSimilarStartTime: Float {
		let fps = FingerprintProperties.fps
		let numRobustPointsPerFrame = FingerprintProperties.numRobustPointsPerFrame
		return (Float(mostSimilarFramePosition) / Float(numRobustPointsPerFrame) / Float(fps))
	}

}
