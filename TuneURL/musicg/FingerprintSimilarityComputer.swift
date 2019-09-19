//
//  FingerprintSimilarityComputer.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class FingerprintSimilarityComputer {

	private var fingerprintSimilarity: FingerprintSimilarity
	var fingerprint1: [UInt8]
	var fingerprint2: [UInt8]

	// MARK: -

	init(fingerprint1: [UInt8], fingerprint2: [UInt8])
	{
		self.fingerprint1 = fingerprint1
		self.fingerprint2 = fingerprint2

		fingerprintSimilarity = FingerprintSimilarity()
	}

	func getFingerprintsSimilarity() -> FingerprintSimilarity
	{
		var offset_Score_Table = [Int : Int]()
		// offset_Score_Table<offset,count>

		var numFrames = 0
		var score: Float = 0.0
		var mostSimilarFramePosition = Int.min

		// one frame may contain several points, use the shorter one be the denominator
		if (fingerprint1.count > fingerprint2.count) {
			numFrames = FingerprintManager.getNumFrames(fingerprint: fingerprint2)
		} else {
			numFrames = FingerprintManager.getNumFrames(fingerprint: fingerprint1)
		}
/*
// TEMP: dump for comparison testing
		print("FingerprintSimilarity: numFrames: \(numFrames)")
// ----
*/
		// get the pairs
		let pairManager = PairManager()
		var this_Pair_PositionList_Table = pairManager.getPair_PositionList_Table(fingerprint1)
		var compareWave_Pair_PositionList_Table = pairManager.getPair_PositionList_Table(fingerprint2)
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
//		Iterator<Integer> compareWaveHashNumberIterator=compareWave_Pair_PositionList_Table.keySet().iterator();
//		while (compareWaveHashNumberIterator.hasNext()){
//			int compareWaveHashNumber=compareWaveHashNumberIterator.next();
		for compareWaveHashNumber in compareWave_Pair_PositionList_Table.keys {
			// if the compareWaveHashNumber doesn't exist in both tables, no need to compare
//			if (!this_Pair_PositionList_Table.containsKey(compareWaveHashNumber) || !compareWave_Pair_PositionList_Table.containsKey(compareWaveHashNumber)) {
			if ((this_Pair_PositionList_Table[compareWaveHashNumber] == nil) || (compareWave_Pair_PositionList_Table[compareWaveHashNumber] == nil)) {
				continue
			}

			// for each compare hash number, get the positions
			let wavePositionList = this_Pair_PositionList_Table[compareWaveHashNumber]
			let compareWavePositionList = compareWave_Pair_PositionList_Table[compareWaveHashNumber]

//			Iterator<Integer> wavePositionListIterator=wavePositionList.iterator();
//			while (wavePositionListIterator.hasNext()) {
//				int thisPosition=wavePositionListIterator.next();
			for thisPosition in wavePositionList! {

//				Iterator<Integer> compareWavePositionListIterator=compareWavePositionList.iterator();
//				while (compareWavePositionListIterator.hasNext()) {
//					int compareWavePosition=compareWavePositionListIterator.next();
				for compareWavePosition in compareWavePositionList! {

					let offset = thisPosition - compareWavePosition

//					if (offset_Score_Table.containsKey(offset)) {
					if let currentScore = offset_Score_Table[offset] {
						offset_Score_Table[offset] = (currentScore + 1)
					} else {
						offset_Score_Table[offset] = 1
					}
				}
			}
		}

		// map rank
		let mapRank = MapRankInteger(offset_Score_Table, ascending: false)

		// get the most similar positions and scores
		let orderedKeyList = mapRank.getOrderedKeyList(100, true)
		if (orderedKeyList.count > 0) {
			let key = orderedKeyList[0]
			// get the highest score position
			if (mostSimilarFramePosition == Int.min) {
				mostSimilarFramePosition = key
				score = Float(offset_Score_Table[key]!)

				// accumulate the scores from neighbours
//				if (offset_Score_Table.containsKey(key - 1)) {
				if let offsetScore = offset_Score_Table[(key - 1)] {
//					score += offset_Score_Table.get(key - 1) / 2
					score += Float(offsetScore / 2)
				}
//				if (offset_Score_Table.containsKey(key + 1)) {
				if let offsetScore = offset_Score_Table[(key + 1)] {
//					score += offset_Score_Table.get(key + 1) / 2
					score += Float(offsetScore / 2)
				}
			}
		}

	/*
	Iterator<Integer> orderedKeyListIterator=orderedKeyList.iterator();
	while (orderedKeyListIterator.hasNext()){
	int offset=orderedKeyListIterator.next();
	System.out.println(offset+": "+offset_Score_Table.get(offset));
	}
	*/

		score /= Float(numFrames)
		var similarity = score
		// similarity >1 means in average there is at least one match in every frame
		if (similarity > 1.0) {
			similarity = 1.0
		}

		fingerprintSimilarity.setMostSimilarFramePosition(mostSimilarFramePosition)
		fingerprintSimilarity.setScore(score)
		fingerprintSimilarity.setSimilarity(similarity)

		return fingerprintSimilarity
	}

}
