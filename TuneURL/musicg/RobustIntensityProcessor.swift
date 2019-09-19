//
//  RobustIntensityProcessor.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/10/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class RobustIntensityProcessor {

	// private
	private var intensities: [[Float]]
	private var numPointsPerFrame: Int

	// MARK: -

	init(intensities: [[Float]], numPointsPerFrame: Int)
	{
		self.intensities = intensities
		self.numPointsPerFrame = numPointsPerFrame
	}

	func execute()
	{
		let numX = intensities.count
		let numY = intensities[0].count
		var processedIntensities = [[Float]](repeating: [Float](repeating: 0.0, count: numY), count: numX)

		for i in 0 ..< numX {

			// TODO: Optimization: Using a sorted array is overkill.
			// Instead find the smallest value and use that as the pass value.

			// pass value is the last some elements in sorted array
			let arrayRankFloat = ArrayRankFloat(array: intensities[i])
			let passValue = arrayRankFloat.getNthOrderedValue(n: numPointsPerFrame, ascending: false)

			// only passed elements will be assigned a value
			for j in 0 ..< numY {
				if (intensities[i][j] >= passValue) {
					processedIntensities[i][j] = intensities[i][j]
				}
			}
		}

		intensities = processedIntensities
	}

	func getIntensities() -> [[Float]]
	{
		return intensities
	}

}
