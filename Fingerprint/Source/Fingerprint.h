//
//  Fingerprint.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

#ifndef FINGERPRINT_H
#define FINGERPRINT_H

#include <stdbool.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

// the audio sample rate required for fingerprinting
#define FINGERPRINT_SAMPLE_RATE		10240.0


typedef struct Fingerprint {

	uint8_t		*data;
	int			dataSize;

} Fingerprint;


typedef struct FingerprintSimilarity {

	int mostSimilarFramePosition;	// the frame number that was most similar
	float mostSimilarStartTime;		// the start time of the most similar section
	float score;					// the number of features matched per frame
	float similarity;				// similarity ranked in range (0.0 - 1.0)
									// 1.0 means that on average there is at least one match every frame.
} FingerprintSimilarity;


FingerprintSimilarity CompareFingerprints(const Fingerprint *fingerprint1, const Fingerprint *fingerprint2, bool truncating);
Fingerprint *ExtractFingerprint(const int16_t *wave, int waveLength);
Fingerprint *ExtractFingerprintFromRawFile(const char *filePath);
void FingerprintFree(Fingerprint *fingerprint);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif /* FINGERPRINT_H */
