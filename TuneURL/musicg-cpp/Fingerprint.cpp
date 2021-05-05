//
//  Fingerprint.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#include "Fingerprint.h"
#include "FingerprintManager.h"

Fingerprint *ExtractFingerprint(const int16_t *wave, int waveLength)
{
	FingerprintManager fingerprinter;

	vector<uint8_t> *fingerprintData = fingerprinter.extractFingerprint(wave, waveLength, false);
	if (fingerprintData == NULL) {
		return NULL;
	}

	// TODO: make a copy of the fingerprint data

	Fingerprint *fingerprint = (Fingerprint*)malloc(sizeof(Fingerprint));
	fingerprint->data = fingerprintData->data();
	fingerprint->dataSize = (int)fingerprintData->size();

	return fingerprint;
}
