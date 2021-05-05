//
//  FingerprintProperties.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#ifndef FingerprintProperties_h
#define FingerprintProperties_h

class FingerprintProperties {

public:

	static int numRobustPointsPerFrame;
	static int sampleSizePerFrame;
	static int overlapFactor;
	static int numFilterBanks;
	static int upperBoundedFrequency;
	static int lowerBoundedFrequency;
	static int fps;
	static float sampleRate;
	static int refMaxActivePairs;
	static int sampleMaxActivePairs;
	static int numAnchorPointsPerInterval;
	static int anchorPointsIntervalLength;
	static int maxTargetZoneDistance;
	static int numFrequencyUnits;

};

#endif // FingerprintProperties_h
