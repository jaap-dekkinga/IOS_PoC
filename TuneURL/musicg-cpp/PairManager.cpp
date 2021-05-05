//
//  PairManager.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

// TEMP
#if IGNORE

#include "PairManager.h"


PairManager::PairManager()
{
	bandwidthPerBank = (numFrequencyUnits / numFilterBanks);
	maxPairs = refMaxActivePairs;
}

PairManager::PairManager(bool isReferencePairing) : isReferencePairing(isReferencePairing)
{
	// Constructor, number of pairs of robust points depends on the parameter isReferencePairing
	// no. of pairs of reference and sample can be different due to environmental influence of source

	bandwidthPerBank = (numFrequencyUnits / numFilterBanks);
	if (isReferencePairing) {
		maxPairs = refMaxActivePairs;
	} else {
		maxPairs = sampleMaxActivePairs;
	}
}

/**
* Get a pair-positionList table
* It's a hash map which the key is the hashed pair, and the value is list of positions
* That means the table stores the positions which have the same hashed pair
*/

[Int : [Int]] PairManager::getPair_PositionList_Table(const vector<uint8_t> &fingerprint)
{
	let pairPositionList = getPairPositionList(fingerprint);

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

	// table to store pair: pos, pos, pos, ...; pair2: pos, pos, pos, ...
	var pair_positionList_table = [Int : [Int]]()

	// get all pair positions from list, use a table to collect the data group by pair hashcode
	for pairPosition in pairPositionList {
		// group by pair-hashcode, i.e.: <pair, List<position>>
		if var array = pair_positionList_table[pairPosition[0]] {
			array.append(pairPosition[1])
			pair_positionList_table[pairPosition[0]] = array
		} else {
			pair_positionList_table[pairPosition[0]] = [ pairPosition[1] ]
		}
	}

	return pair_positionList_table
}

// MARK: -
// MARK: Private

// this return list contains: int[0] = pair_hashcode, int[1] = position
vector<vector<int>> PairManager::getPairPositionList(const vector<uint8_t> &fingerprint)
{
	let numFrames = FingerprintManager.getNumFrames(fingerprint);

	// table for paired frames
	var pairedFrameTable = [UInt8](repeating: 0, count: (numFrames / anchorPointsIntervalLength + 1));
	// each second has numAnchorPointsPerSecond pairs only

	var pairList = [[Int]]();
	let sortedCoordinateList = getSortedCoordinateList(fingerprint: fingerprint);

	for anchorPoint in sortedCoordinateList {
		var numPairs = 0;

		for targetPoint in sortedCoordinateList {

			if (numPairs >= maxPairs) {
				break;
			}

			if (isReferencePairing && pairedFrameTable[anchorPoint.x / anchorPointsIntervalLength] >= numAnchorPointsPerInterval) {
				break;
			}

			if ((anchorPoint.x == targetPoint.x) && (anchorPoint.y == targetPoint.y)) {
				continue;
			}

			// pair up the points
			int x1;
			int y1;
			int x2;
			int y2;	// x2 always >= x1

			if (targetPoint.x >= anchorPoint.x) {
				x2 = targetPoint.x;
				y2 = targetPoint.y;
				x1 = anchorPoint.x;
				y1 = anchorPoint.y;
			} else {
				x2 = anchorPoint.x;
				y2 = anchorPoint.y;
				x1 = targetPoint.x;
				y1 = targetPoint.y;
			}

			// check target zone
			if ((x2 - x1) > maxTargetZoneDistance) {
				continue;
			}

			// check filter bank zone
			if (!((y1 / bandwidthPerBank) == (y2 / bandwidthPerBank))) {
				// same filter bank should have equal value
				continue;
			}

			let pairHashcode = (x2 - x1) * numFrequencyUnits * numFrequencyUnits + y2 * numFrequencyUnits + y1;

			// stop list applied on sample pairing only
			if (!isReferencePairing && (stopPairTable[pairHashcode] != nil)) {
				numPairs += 1;	// no reservation
				continue;	// escape this point only
			}

			// pass all rules
			pairList.append([pairHashcode, anchorPoint.x]);
			pairedFrameTable[anchorPoint.x / anchorPointsIntervalLength] += 1;
			numPairs += 1;
		}
	}

	return pairList;
}

vector<ArrayCoord> PairManager::getSortedCoordinateList(const vector<uint8> &fingerprint)
{
	// each point data is 8 bytes
	// x: 2 byte integer
	// y: 2 byte integer
	// intensity: 4 bytes

	// get all intensities
	int numCoordinates = ((int)fingerprint.size() / 8);
	vector<int> intensities(numCoordinates);

	for (int i = 0; i < numCoordinates; i++) {
		int pointer = (i * 8 + 4);
		int intensity = (int)(fingerprint[pointer] & 0xFF) << 24 | (int)(fingerprint[pointer + 1] & 0xFF) << 16 | (int)(fingerprint[pointer + 2] & 0xFF) << 8 | (int)(fingerprint[pointer + 3] & 0xFF);
		intensities[i] = intensity;
	}

	let quicksort = QuickSortInteger(intensities);
	let sortIndexes = quicksort.getSortIndexes();

	vector<ArrayCoord> sortedCoordinateList;
	int i = ((int)sortIndexes.size() - 1);

	while (i >= 0) {
		int pointer = (sortIndexes[i] * 8);
		int x = ((int)fingerprint[pointer + 0]) << 8) | (int)fingerprint[pointer + 1]);
		int y = ((int)fingerprint[pointer + 2]) << 8) | (int)fingerprint[pointer + 3]);
		sortedCoordinateList.push_back(ArrayCoord(x, y));
		i -= 1;
	}

/*
	// TEMP: dump for comparison testing
	printf("sortedCoordinateList:\n");
	for (int c = 0; c < (int)sortIndexes.size(); c++) {
		ArrayCoord pos = sortedCoordinateList[c];
		printf("\t%d: %d - %d, %d\n", sortIndexes[c], intensities[sortIndexes[c]], pos.x, pos.y);
	}
	// ----
*/

	return sortedCoordinateList;
}

// TEMP
#endif // IGNORE
