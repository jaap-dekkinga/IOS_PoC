//
//  Fingerprint.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//


#include <cmath>
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

// MARK: - Audio helpers for the local trigger check

static inline int16_t clampToInt16(double value)
{
	if (value > 32767.0) return 32767;
	if (value < -32768.0) return -32768;
	return (int16_t)lround(value);
}

void FingerprintHighPass(int16_t *samples, int count, double sampleRate, double cutoffHz)
{
	if ((samples == NULL) || (count <= 0) || (sampleRate <= 0.0) || (cutoffHz <= 0.0) || (cutoffHz >= (sampleRate / 2.0))) {
		return;
	}

	// two RBJ high-pass biquads with the Q values of a 4th-order Butterworth
	const double qValues[2] = { 0.54119610, 1.30656296 };
	const double w0 = 2.0 * M_PI * cutoffHz / sampleRate;
	const double cosW0 = cos(w0);
	const double sinW0 = sin(w0);

	vector<double> signal(count);
	for (int i = 0; i < count; i++) {
		signal[i] = (double)samples[i];
	}

	for (int stage = 0; stage < 2; stage++) {
		double alpha = sinW0 / (2.0 * qValues[stage]);
		double a0 = 1.0 + alpha;
		double b0 = ((1.0 + cosW0) / 2.0) / a0;
		double b1 = (-(1.0 + cosW0)) / a0;
		double b2 = b0;
		double a1 = (-2.0 * cosW0) / a0;
		double a2 = (1.0 - alpha) / a0;

		double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
		for (int i = 0; i < count; i++) {
			double x0 = signal[i];
			double y0 = (b0 * x0) + (b1 * x1) + (b2 * x2) - (a1 * y1) - (a2 * y2);
			x2 = x1; x1 = x0;
			y2 = y1; y1 = y0;
			signal[i] = y0;
		}
	}

	for (int i = 0; i < count; i++) {
		samples[i] = clampToInt16(signal[i]);
	}
}

int FingerprintAddRoomEcho(const int16_t *input, int16_t *output, int count, double sampleRate, double rt60Seconds, uint32_t seed)
{
	if ((input == NULL) || (output == NULL) || (count <= 0) || (sampleRate <= 0.0) || (rt60Seconds <= 0.0)) {
		return -1;
	}

	// room response: direct sound after 3 ms, plus noise decaying by 60 dB over rt60
	int tailLength = (int)(rt60Seconds * 1.2 * sampleRate);
	if (tailLength < 1) tailLength = 1;
	vector<double> response(tailLength, 0.0);

	uint32_t state = (seed != 0) ? seed : 0x9E3779B9u;
	double tailEnergy = 0.0;
	for (int i = 1; i < tailLength; i++) {
		// xorshift32, mapped to [-1, 1)
		state ^= state << 13; state ^= state >> 17; state ^= state << 5;
		double noise = ((double)state / 2147483648.0) - 1.0;
		double t = (double)i / sampleRate;
		response[i] = noise * exp(-6.9 * t / rt60Seconds);
		tailEnergy += response[i] * response[i];
	}
	double tailScale = (tailEnergy > 0.0) ? (0.7 / sqrt(tailEnergy)) : 0.0;
	for (int i = 1; i < tailLength; i++) {
		response[i] *= tailScale;
	}
	int directIndex = (int)lround(0.003 * sampleRate);
	if (directIndex >= tailLength) directIndex = tailLength - 1;
	response[directIndex] += 1.0;

	// convolve, keeping the input's length
	vector<double> echoed(count, 0.0);
	double inputPeak = 0.0, echoedPeak = 0.0;
	for (int n = 0; n < count; n++) {
		double sample = (double)input[n];
		if (fabs(sample) > inputPeak) inputPeak = fabs(sample);
		if (sample == 0.0) continue;
		int last = ((count - n) < tailLength) ? (count - n) : tailLength;
		for (int k = 0; k < last; k++) {
			echoed[n + k] += sample * response[k];
		}
	}
	for (int n = 0; n < count; n++) {
		if (fabs(echoed[n]) > echoedPeak) echoedPeak = fabs(echoed[n]);
	}

	// match the input's peak level
	double gain = (echoedPeak > 0.0) ? (inputPeak / echoedPeak) : 0.0;
	for (int n = 0; n < count; n++) {
		output[n] = clampToInt16(echoed[n] * gain);
	}

	return 0;
}
