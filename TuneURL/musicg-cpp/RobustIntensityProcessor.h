//
//  RobustIntensityProcessor.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#include <vector>

using std::vector;

class RobustIntensityProcessor {

public:

	vector<vector<float>> intensities;
	int numPointsPerFrame;

	RobustIntensityProcessor(const vector<vector<float>> &intensities, int numPointsPerFrame);
	void execute();

};
