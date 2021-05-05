//
//  Spectrogram.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//


#include "FastFourierTransform.h"
#include "Spectrogram.h"
#include "WindowFunction.h"


Spectrogram::Spectrogram(vector<int16_t> wave, int fftSampleSize, int overlapFactor) : fftSampleSize(fftSampleSize), overlapFactor(overlapFactor)
{
	waveData = wave;
	waveDuration = ((float)waveData.size() / sampleRate);

	buildSpectrogram();
}


// MARK: -
// MARK: Private

void Spectrogram::buildSpectrogram()
{
	vector<int16_t> amplitudes = waveData;
	int numSamples = (int)amplitudes.size();

	// create the overlapping amplitude data
	if (overlapFactor > 1) {
		int numOverlappedSamples = (numSamples * overlapFactor);
		int backSamples = fftSampleSize * (overlapFactor - 1) / overlapFactor;
		int fftSampleSize_1 = (fftSampleSize - 1);
		vector<int16_t> overlapAmp(numOverlappedSamples);
		int pointer = 0;
		int i = 0;
		while (i < (int)amplitudes.size()) {
			overlapAmp[pointer] = amplitudes[i];
			pointer += 1;
			if ((pointer % fftSampleSize) == fftSampleSize_1) {
				// overlap
				i -= backSamples;
			}
			i += 1;
		}
		numSamples = numOverlappedSamples;
		amplitudes = overlapAmp;
	}

/*
	// TEMP: dump for comparison testing
	printf("buildSpectrogram amplitudes (%d):\n", (int)amplitudes.size());
	for (int c = 0; c < 5000; c++) {
		printf("\t%d: %d\n", c, amplitudes[c]);
	}
	// ----
*/

	// number of frames of the spectrogram
	int numFrames = (numSamples / fftSampleSize);

	// TODO: Optimization: Use vDSP for the window function.

	// create the signals array for fft
	WindowFunction windowFunction;
	windowFunction.windowType = WindowFunctionType::hamming;
	vector<float> window = windowFunction.generate(fftSampleSize);

//	var signals = [[Float]](repeating: [Float](repeating: 0.0, count: fftSampleSize), count: numFrames);
	vector<vector<float>> signals(numFrames);
	for (int x = 0; x < numFrames; x++) {
		signals[x].resize(fftSampleSize);
	}

	for (int frameIndex = 0; frameIndex < numFrames; frameIndex++) {
		int startSample = (frameIndex * fftSampleSize);
		for (int n = 0; n < fftSampleSize; n++) {
			signals[frameIndex][n] = ((float)amplitudes[startSample + n] * window[n]);
		}
	}

/*
	// TEMP: dump for comparison testing
	printf("buildSpectrogram signals (%d):\n", (int)signals.size());
	for (int c = 0; c < (int)signals[42].size(); c++) {
		printf("\t%d: %1.16f\n", c, signals[42][c]);
	}
	// ----
*/

	// TODO: Optimization: Move the FFT setup elsewhere (instead of setting up every time).

//	absoluteSpectrogram = [[Float]](repeating: [Float](), count: numFrames);
	absoluteSpectrogram.resize(numFrames);
	// for each frame in signals, do fft on it
	FastFourierTransform fft(fftSampleSize);
	for (int i = 0; i < numFrames; i++) {
		absoluteSpectrogram[i] = fft.getMagnitudes(signals[i]);
	}

/*
	// TEMP: dump for comparison testing
	printf("buildSpectrogram absoluteSpectrogram (%d):\n", (int)absoluteSpectrogram.size());
	for (int c = 0; c < (int)absoluteSpectrogram[42].size(); c++) {
		printf("\t%d: %1.16f\n", c, absoluteSpectrogram[42][c]);
	}
	// ----
*/

	if (absoluteSpectrogram.size() > 0) {

		// number of y-axis unit
		int numFrequencyUnit = (int)absoluteSpectrogram[0].size();

		// get max and min amplitudes of the absoluteSpectrogram
		float maxAmplitude = FLT_MIN;
		float minAmplitude = FLT_MAX;

		for(int i = 0; i < numFrames; i++) {
			for (int j = 0; j < numFrequencyUnit; j++) {
				if (absoluteSpectrogram[i][j] > maxAmplitude) {
					maxAmplitude = absoluteSpectrogram[i][j];
				} else if (absoluteSpectrogram[i][j] < minAmplitude) {
					minAmplitude = absoluteSpectrogram[i][j];
				}
			}
		}

		// safety check the minimum amplitude to avoid divide by zero
		float minValidAmplitude = 0.00000000001f;
		if (minAmplitude == 0.0f) {
			minAmplitude = minValidAmplitude;
		}

		// normalize the absolute spectrogram
//		spectrogram = [[Float]](repeating: [Float](repeating: 0.0, count: numFrequencyUnit), count: numFrames);
		spectrogram.resize(numFrames);
		for (int x = 0; x < numFrames; x++) {
			spectrogram[x].resize(numFrequencyUnit);
		}

		float diff = log10f(maxAmplitude / minAmplitude);	// perceptual difference
		for (int i = 0; i < numFrames; i++) {
			for (int j = 0; j < numFrequencyUnit; j++) {
				if (absoluteSpectrogram[i][j] < minValidAmplitude) {
					spectrogram[i][j] = 0.0f;
				} else {
					spectrogram[i][j] = ((log10f(absoluteSpectrogram[i][j] / minAmplitude)) / diff);
				}
			}
		}
/*
		// TEMP: dump for comparison testing
		printf("buildSpectrogram spectrogram (%d):\n", (int)spectrogram.size());
		for (int c = 0; c < (int)spectrogram[0].size(); c++) {
			printf("\t%d: %1.16f\n", c, spectrogram[0][c]);
		}
		// ----
*/
	}
}
