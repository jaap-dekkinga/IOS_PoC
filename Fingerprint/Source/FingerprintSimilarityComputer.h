//
//  FingerprintSimilarityComputer.h
//  TuneURL
//

#ifndef FINGERPRINTSIMILARITYCOMPUTER_H
#define FINGERPRINTSIMILARITYCOMPUTER_H

#include <cstdint>
#include <vector>
#include "Fingerprint.h"

using std::vector;

class FingerprintSimilarityComputer {

public:

	FingerprintSimilarityComputer(const vector<uint8_t> &fingerprint1, const vector<uint8_t> &fingerprint2, int hashProtocolVersion = 1);

	FingerprintSimilarity getMatchResults();

private:

	vector<uint8_t> fingerprint1;
	vector<uint8_t> fingerprint2;
	int hashProtocolVersion { 1 };

};

#endif /* FINGERPRINTSIMILARITYCOMPUTER_H */
