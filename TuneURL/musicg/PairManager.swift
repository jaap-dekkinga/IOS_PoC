//
//  PairManager.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class PairManager {

	// private
	private let fps = FingerprintProperties.fps
	private let numFilterBanks = FingerprintProperties.numFilterBanks
	private let anchorPointsIntervalLength = FingerprintProperties.anchorPointsIntervalLength
	private let numAnchorPointsPerInterval = FingerprintProperties.numAnchorPointsPerInterval
	private let refMaxActivePairs = FingerprintProperties.refMaxActivePairs
	private let sampleMaxActivePairs = FingerprintProperties.sampleMaxActivePairs
	private let upperBoundedFrequency = FingerprintProperties.upperBoundedFrequency
	private let lowerBoundedFrequency = FingerprintProperties.lowerBoundedFrequency
	private let maxTargetZoneDistance = FingerprintProperties.maxTargetZoneDistance
	private let numFrequencyUnits = FingerprintProperties.numFrequencyUnits

	private var bandwidthPerBank: Int
	private var maxPairs: Int
	private var isReferencePairing: Bool
	private var stopPairTable = [Int : Bool]()

	// MARK: -

	init()
	{
		bandwidthPerBank = (numFrequencyUnits / numFilterBanks)

		maxPairs = refMaxActivePairs
		isReferencePairing = true
	}

	/**
	* Constructor, number of pairs of robust points depends on the parameter isReferencePairing
	* no. of pairs of reference and sample can be different due to environmental influence of source
	*/

	init(isReferencePairing: Bool)
	{
		bandwidthPerBank = (numFrequencyUnits / numFilterBanks)

		if (isReferencePairing) {
			maxPairs = refMaxActivePairs
		} else {
			maxPairs = sampleMaxActivePairs
		}

		self.isReferencePairing = isReferencePairing
	}

	/**
	* Get a pair-positionList table
	* It's a hash map which the key is the hashed pair, and the value is list of positions
	* That means the table stores the positions which have the same hashed pair
	*
	* @param fingerprint	fingerprint bytes
	* @return pair-positionList HashMap
	*/

	func getPair_PositionList_Table(_ fingerprint: [UInt8]) -> [Int : [Int]]
	{
		let pairPositionList = getPairPositionList(fingerprint: fingerprint)
/*
// TEMP: dump for comparison testing
		print("pairPositionList:")
		var string = "\t"
		for value in pairPositionList {
			string += "\(value)"
		}
		print(string)
// ----
*/
		// table to store pair:pos,pos,pos,...;pair2:pos,pos,pos,....
		var pair_positionList_table = [Int : [Int]]()

		// get all pair_positions from list, use a table to collect the data group by pair hashcode
//		Iterator<int[]> pairPositionListIterator=pairPositionList.iterator();
//		while (pairPositionListIterator.hasNext()) {
//			int[] pair_position=pairPositionListIterator.next();
		for pair_position in pairPositionList {
			//System.out.println(pair_position[0]+","+pair_position[1]);

			// group by pair-hashcode, i.e.: <pair,List<position>>
//			if (pair_positionList_table.containsKey(pair_position.x)) {
			if var currentArray = pair_positionList_table[pair_position[0]] {
//				pair_positionList_table.get(pair_position.x).append(pair_position.y)
				currentArray.append(pair_position[1])
				pair_positionList_table[pair_position[0]] = currentArray
			} else {
//				List<Integer> positionList=new LinkedList<Integer>()
//				positionList.append(pair_position.y)
				pair_positionList_table[pair_position[0]] = [pair_position[1]]
			}
			// end group by pair-hashcode, i.e.: <pair,List<position>>
		}
		// end get all pair_positions from list, use a table to collect the data group by pair hashcode

		return pair_positionList_table
	}

	// this return list contains: int[0]=pair_hashcode, int[1]=position
	func getPairPositionList(fingerprint: [UInt8]) -> [[Int]]
	{
		let numFrames = FingerprintManager.getNumFrames(fingerprint: fingerprint)

		// table for paired frames
		var pairedFrameTable = [UInt8](repeating: 0, count: (numFrames / anchorPointsIntervalLength + 1))
		// each second has numAnchorPointsPerSecond pairs only
		// end table for paired frames

		var pairList = [[Int]]()
		let sortedCoordinateList = getSortedCoordinateList(fingerprint: fingerprint)

//		Iterator<int[]> anchorPointListIterator = sortedCoordinateList.iterator();
//		while (anchorPointListIterator.hasNext()) {
//			int[] anchorPoint=anchorPointListIterator.next();
		for anchorPoint in sortedCoordinateList {
			let anchorX = anchorPoint.x
			let anchorY = anchorPoint.y
			var numPairs = 0

//			Iterator<int[]> targetPointListIterator = sortedCoordinateList.iterator()
//			while (targetPointListIterator.hasNext()) {
			for targetPoint in sortedCoordinateList {

				if (numPairs >= maxPairs) {
					break
				}

				if (isReferencePairing && pairedFrameTable[anchorX / anchorPointsIntervalLength] >= numAnchorPointsPerInterval) {
					break
				}

//				int[] targetPoint=targetPointListIterator.next();
				let targetX = targetPoint.x
				let targetY = targetPoint.y

				if (anchorX == targetX && anchorY == targetY) {
					continue
				}

				// pair up the points
				var x1: Int
				var y1: Int
				var x2: Int
				var y2: Int	// x2 always >= x1

				if (targetX >= anchorX) {
					x2 = targetX
					y2 = targetY
					x1 = anchorX
					y1 = anchorY
				} else {
					x2 = anchorX
					y2 = anchorY
					x1 = targetX
					y1 = targetY
				}

				// check target zone
				if ((x2 - x1) > maxTargetZoneDistance) {
					continue
				}
				// end check target zone

				// check filter bank zone
				if (!(y1 / bandwidthPerBank == y2 / bandwidthPerBank)) {
					// same filter bank should have equal value
					continue
				}
				// end check filter bank zone

				let pairHashcode = (x2 - x1) * numFrequencyUnits * numFrequencyUnits + y2 * numFrequencyUnits + y1

				// stop list applied on sample pairing only
				if (!isReferencePairing && (stopPairTable[pairHashcode] != nil)) {
					numPairs += 1	// no reservation
					continue	// escape this point only
				}
				// end stop list applied on sample pairing only

				// pass all rules
				pairList.append([pairHashcode, anchorX])
				pairedFrameTable[anchorX / anchorPointsIntervalLength] += 1
				//System.out.println(anchorX+","+anchorY+"&"+targetX+","+targetY+":"+pairHashcode+" ("+pairedFrameTable[anchorX/anchorPointsIntervalLength]+")");
				numPairs += 1
				// end pair up the points
			}
		}

		return pairList
	}

	// MARK: -
	// MARK: Private

	private func getSortedCoordinateList(fingerprint: [UInt8]) -> [ArrayCoord]
	{
		// each point data is 8 bytes
		// first 2 bytes is x
		// next 2 bytes is y
		// next 4 bytes is intensity

		// get all intensities
		let numCoordinates = fingerprint.count / 8
		var intensities = [Int](repeating: 0, count: numCoordinates)
		for i in 0 ..< numCoordinates {
			let pointer = i * 8 + 4
			let intensity = Int(fingerprint[pointer] & 0xFF) << 24 | Int(fingerprint[pointer + 1] & 0xFF) << 16 | Int(fingerprint[pointer + 2] & 0xFF) << 8 | Int(fingerprint[pointer + 3] & 0xFF)
			intensities[i] = intensity
		}

		let quicksort = QuickSortInteger(intensities)
		let sortIndexes = quicksort.getSortIndexes()

		var sortedCoordinateList = [ArrayCoord]()
//		for (int i = sortIndexes.count - 1; i >= 0; i--) {
		var i = (sortIndexes.count - 1)
		while (i >= 0) {
			let pointer = sortIndexes[i] * 8
			let x = (Int(fingerprint[pointer + 0]) << 8) | Int(fingerprint[pointer + 1])
			let y = (Int(fingerprint[pointer + 2]) << 8) | Int(fingerprint[pointer + 3])
			sortedCoordinateList.append(ArrayCoord(x: x, y: y))
			i -= 1
		}
/*
		// TEMP: dump for comparison testing
		print("sortedCoordinateList:")
		for c in 0 ..< sortIndexes.count {
			let pos = sortedCoordinateList[c]
			print("\t\(sortIndexes[c]): \(intensities[sortIndexes[c]]) - \(pos.x), \(pos.y)")
		}
		// ----
*/
		return sortedCoordinateList
	}

}
