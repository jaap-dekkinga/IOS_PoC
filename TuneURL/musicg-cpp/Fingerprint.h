//
//  Fingerprint.h
//  TuneURL
//
//  Created by Gerrit on 5/4/21.
//  Copyright © 2021 TuneURL Inc. All rights reserved.
//

#ifndef Fingerprint_h
#define Fingerprint_h

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

typedef struct Fingerprint {

	uint8_t		*data;
	int			dataSize;

} Fingerprint;

Fingerprint *ExtractFingerprint(const int16_t *wave, int waveLength);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // Fingerprint_h
