//
//  FingerprintSimilarityComputer.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#include <vector>
#include "FingerprintSimilarity.h"

using std::vector;

class FingerprintSimilarityComputer {

public:

	FingerprintSimilarityComputer(const vector<uint8> &fingerprint1, const vector<uint8> &fingerprint2)
	FingerprintSimilarity getMatchResults();

private:

	vector<uint8> fingerprint1;
	vector<uint8> fingerprint2;

}
