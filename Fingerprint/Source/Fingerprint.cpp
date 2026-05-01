//
//  Fingerprint.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//


#include <cstdio>
#include <cstring>
#include "Fingerprint.h"
#include "FingerprintManager.h"
#include "FingerprintSimilarityComputer.h"


// detect the hash protocol version and return a pointer past any header bytes,
// writing the effective landmark byte count into outLandmarkSize. Returns -1 on
// unknown/unsupported version.
static int detectVersion(const uint8_t *data, int dataSize, int *outHeaderSize)
{
	if ((data != NULL) && (dataSize >= FINGERPRINT_HEADER_SIZE) && (data[0] == FINGERPRINT_MAGIC)) {
		int hashProtocol = (int)data[2];
		if ((hashProtocol != HASH_PROTOCOL_V1) && (hashProtocol != HASH_PROTOCOL_V2)) {
			return -1; // unknown hash protocol
		}
		*outHeaderSize = FINGERPRINT_HEADER_SIZE;
		return hashProtocol;
	}
	// no magic byte means legacy v1
	*outHeaderSize = 0;
	return HASH_PROTOCOL_V1;
}

FingerprintSimilarity CompareFingerprints(const Fingerprint *fingerprint1, const Fingerprint *fingerprint2)
{
	FingerprintSimilarity emptyResult;
	emptyResult.mostSimilarFramePosition = 0;
	emptyResult.mostSimilarStartTime = 0.0f;
	emptyResult.score = 0.0f;
	emptyResult.similarity = 0.0f;

	// detect and strip headers
	int header1 = 0, header2 = 0;
	int version1 = detectVersion(fingerprint1->data, fingerprint1->dataSize, &header1);
	int version2 = detectVersion(fingerprint2->data, fingerprint2->dataSize, &header2);

	// reject unknown or mismatched versions
	if ((version1 < 0) || (version2 < 0) || (version1 != version2)) {
		return emptyResult;
	}

	size_t size1 = (size_t)(fingerprint1->dataSize - header1);
	size_t size2 = (size_t)(fingerprint2->dataSize - header2);

	// select the smaller fingerprint size
	size_t dataSize = (size1 > size2) ? size2 : size1;

	// copy the fingerprint data (past the header)
	vector<uint8_t> data1(dataSize);
	memcpy(data1.data(), fingerprint1->data + header1, dataSize);
	vector<uint8_t> data2(dataSize);
	memcpy(data2.data(), fingerprint2->data + header2, dataSize);

	FingerprintSimilarityComputer computer(data1, data2, version1);
	return computer.getMatchResults();
}

Fingerprint *ExtractFingerprint(const int16_t *wave, int waveLength, int emitVersion)
{
	// extract the fingerprint
	FingerprintManager fingerprinter;
	fingerprinter.setHashProtocolVersion((emitVersion == FORMAT_VERSION_V2) ? HASH_PROTOCOL_V2 : HASH_PROTOCOL_V1);
	vector<uint8_t> *fingerprintData = fingerprinter.extractFingerprint(wave, waveLength);
	if (fingerprintData == NULL) {
		return NULL;
	}

	// create the fingerprint
	Fingerprint *fingerprint = (Fingerprint*)malloc(sizeof(Fingerprint));

	if (emitVersion == FORMAT_VERSION_V2) {
		// prepend 4-byte header: magic, format version, hash protocol version, calibration version
		fingerprint->dataSize = (int)fingerprintData->size() + FINGERPRINT_HEADER_SIZE;
		fingerprint->data = (uint8_t*)malloc(fingerprint->dataSize);
		fingerprint->data[0] = FINGERPRINT_MAGIC;
		fingerprint->data[1] = FORMAT_VERSION_V2;
		fingerprint->data[2] = HASH_PROTOCOL_V2;
		fingerprint->data[3] = CALIBRATION_VERSION_V2;
		memcpy(fingerprint->data + FINGERPRINT_HEADER_SIZE, fingerprintData->data(), fingerprintData->size());
	} else {
		// v1: no header, byte-identical to legacy format
		fingerprint->dataSize = (int)fingerprintData->size();
		fingerprint->data = (uint8_t*)malloc(fingerprint->dataSize);
		memcpy(fingerprint->data, fingerprintData->data(), fingerprint->dataSize);
	}

	return fingerprint;
}

Fingerprint *ExtractFingerprintFromRawFile(const char *filePath, int emitVersion)
{
	// open the file
	FILE *file = fopen(filePath, "rb");
	if (file == NULL) {
		return NULL;
	}

	// get the file size
	fseek(file, 0L, SEEK_END);
	int fileSize = (int)ftell(file);
	rewind(file);
	if ((fileSize <= 0) || ((fileSize & 0x1) != 0)) {
		return NULL;
	}

	// allocate the buffer
	void *fileBuffer = malloc(fileSize);
	if (fileBuffer == NULL) {
		return NULL;
	}

	// read the file
	if (fread(fileBuffer, 1, fileSize, file) != fileSize) {
		free(fileBuffer);
		return NULL;
	}

	// generate the fingerprint
	Fingerprint *fingerprint = ExtractFingerprint((const int16_t*)fileBuffer, (fileSize >> 1), emitVersion);
	if (fingerprint == NULL) {
		free(fileBuffer);
		return NULL;
	}

	// cleanup
	free(fileBuffer);

	return fingerprint;
}

void FingerprintFree(Fingerprint *fingerprint)
{
	// release the fingerprint
	if (fingerprint != NULL) {
		if (fingerprint->data != NULL) {
			free(fingerprint->data);
		}
		free(fingerprint);
	}
}
