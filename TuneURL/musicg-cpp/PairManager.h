//
//  PairManager.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#include <map>
#include <vector>
#include "ArrayCoord.h"
#include "FingerprintProperties.h"

using std::vector;

class PairManager {

public:

	PairManager();
	PairManager(bool isReferencePairing);

	[Int : [Int]] getPair_PositionList_Table(const vector<uint8_t> &fingerprint);

private:

	int fps { FingerprintProperties::fps };
	int numFilterBanks { FingerprintProperties::numFilterBanks };
	int anchorPointsIntervalLength { FingerprintProperties::anchorPointsIntervalLength };
	int numAnchorPointsPerInterval { FingerprintProperties::numAnchorPointsPerInterval };
	int refMaxActivePairs { FingerprintProperties::refMaxActivePairs };
	int sampleMaxActivePairs { FingerprintProperties::sampleMaxActivePairs };
	int upperBoundedFrequency { FingerprintProperties::upperBoundedFrequency };
	int lowerBoundedFrequency { FingerprintProperties::lowerBoundedFrequency };
	int maxTargetZoneDistance { FingerprintProperties::maxTargetZoneDistance };
	int numFrequencyUnits { FingerprintProperties::numFrequencyUnits };

	int bandwidthPerBank;
	int maxPairs;
	bool isReferencePairing { true };
	std::map<int, bool> stopPairTable;


	vector<vector<int>> getPairPositionList(const vector<uint8_t> &fingerprint);
	vector<ArrayCoord> getSortedCoordinateList(const vector<uint8_t> &fingerprint);

};
