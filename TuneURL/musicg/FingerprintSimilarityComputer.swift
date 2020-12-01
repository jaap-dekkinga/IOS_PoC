//
//  FingerprintSimilarityComputer.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class FingerprintSimilarityComputer {

	// private
	private var fingerprint1: [UInt8]
	private var fingerprint2: [UInt8]

	// MARK: -

	init(fingerprint1: [UInt8], fingerprint2: [UInt8])
	{
		self.fingerprint1 = fingerprint1
		self.fingerprint2 = fingerprint2
	}

	func getMatchResults() -> FingerprintSimilarity
	{
		let results = FingerprintSimilarity()
		var offsetScoreTable = [Int : Int]()
		var numFrames = 0

		// reset the results
		results.score = 0.0
		results.similarity = 0.0
		results.mostSimilarFramePosition = Int.min

		// one frame may contain several points, use the shorter one be the denominator
		if (fingerprint1.count > fingerprint2.count) {
			numFrames = FingerprintManager.getNumFrames(fingerprint: fingerprint2)
		} else {
			numFrames = FingerprintManager.getNumFrames(fingerprint: fingerprint1)
		}

/*
// TEMP: dump for comparison testing
		print("FingerprintSimilarityComputer: numFrames: \(numFrames)")
// ----
*/

		// get the pairs
		let pairManager = PairManager()
        let this_Pair_PositionList_Table = pairManager.getPair_PositionList_Table(fingerprint1)
        let compareWave_Pair_PositionList_Table = pairManager.getPair_PositionList_Table(fingerprint2)

/*
// TEMP: dump for comparison testing
		// [Int : [Int]]
		print("this_Pair_PositionList_Table:")
		for (key, value) in this_Pair_PositionList_Table {
			var string = "\t\(key): "
			for subvalue in value {
				string += "\(subvalue),"
			}
			print(string)
		}
// ----
*/

		for compareWaveHashNumber in compareWave_Pair_PositionList_Table.keys {

			// for each compare hash number, get the positions
			// if the compareWaveHashNumber in either table, no need to compare
			guard let wavePositionList = this_Pair_PositionList_Table[compareWaveHashNumber] else {
				continue
			}
			guard let compareWavePositionList = compareWave_Pair_PositionList_Table[compareWaveHashNumber] else {
				continue
			}

			for thisPosition in wavePositionList {
				for compareWavePosition in compareWavePositionList {
					let offset = (thisPosition - compareWavePosition)

					if let currentScore = offsetScoreTable[offset] {
						offsetScoreTable[offset] = (currentScore + 1)
					} else {
						offsetScoreTable[offset] = 1
					}
				}
			}
		}

		// map rank
		let mapRank = MapRankInteger(offsetScoreTable, ascending: false)

		// get the most similar positions and scores
		let orderedKeyList = mapRank.getOrderedKeyList(100, true)
		if (orderedKeyList.count > 0) {
			let key = orderedKeyList[0]

			// get the highest score position
			if (results.mostSimilarFramePosition == Int.min) {
				results.mostSimilarFramePosition = key
				results.score = Float(offsetScoreTable[key]!)

				// accumulate the scores from neighbors
				if let offsetScore = offsetScoreTable[(key - 1)] {
					results.score += Float(offsetScore / 2)
				}
				if let offsetScore = offsetScoreTable[(key + 1)] {
					results.score += Float(offsetScore / 2)
				}
			}
		}

		results.score /= Float(numFrames)
		results.similarity = results.score
		if (results.similarity > 1.0) {
			// similarity > 1.0 means in average there is at least one match in every frame
			results.similarity = 1.0
		}

		return results
	}

}
