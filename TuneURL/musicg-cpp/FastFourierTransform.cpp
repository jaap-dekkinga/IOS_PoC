//
//  FastFourierTransform.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//


#include "FastFourierTransform.h"


FastFourierTransform::FastFourierTransform(int numberOfSamples)
{
	fftFrameSize = (numberOfSamples / 2);

	vDSP_Length log2n = (vDSP_Length)log2f((float)fftFrameSize);

	complexARealP.resize(fftFrameSize);
	complexAImagP.resize(fftFrameSize);
	outFFTData.resize(fftFrameSize / 2);

	fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
}

FastFourierTransform::~FastFourierTransform()
{
	if (fftSetup != nil) {
		vDSP_destroy_fftsetup(fftSetup);
		fftSetup = nil;
	}
}

vector<float> FastFourierTransform::getMagnitudes(const vector<float> &timeDomainData)
{
	// safety check
	if (fftSetup == nil) {
		return outFFTData;
	}

	vDSP_Length log2n = (vDSP_Length)log2f((float)fftFrameSize);

	// copy the contents of an interleaved complex vector C to a split complex vector Z; single precision.
	const DSPComplex *complex = (const DSPComplex*)timeDomainData.data();
	DSPSplitComplex complexA;
	complexA.realp = complexARealP.data();
	complexA.imagp = complexAImagP.data();
	vDSP_ctoz(complex, 2, &complexA, 1, fftFrameSize);

	// Perform FFT using fftSetup and A
	// Results are returned in A

	// in-place single-precision complex discrete Fourier transform
	vDSP_fft_zip(fftSetup, &complexA, 1, log2n, (FFTDirection)FFT_FORWARD);

/*
	// Complex vector magnitudes squared; single precision.
	vDSP_zvmags(&complexA, 1, outDataPointer, 1, fftFrameSize);
*/

	// TODO: perform this step with vDSP

	for (int c = 0; c < (int)outFFTData.size(); c++) {
		float value = (complexARealP[c] * complexARealP[c]) + (complexAImagP[c] * complexAImagP[c]);
		outFFTData[c] = sqrtf(value);
	}

	return outFFTData;
}
/*
 vector<float> FastFourierTransform::getMagnitudes(const vector<float> &timeDomainData)
{
	let sampleSize = (int)amplitudes.size();

	// call the fft and transform the complex numbers
	FFT fft = new FFT(sampleSize / 2, -1);
	fft.transform(amplitudes);
	// end call the fft and transform the complex numbers

	double[] complexNumbers = amplitudes;

	// even indexes (0,2,4,6,...) are real parts
	// odd indexes (1,3,5,7,...) are img parts
	int indexSize = sampleSize / 2;

	// FFT produces a transformed pair of arrays where the first half of the
	// values represent positive frequency components and the second half
	// represents negative frequency components.
	// we omit the negative ones
	int positiveSize = indexSize / 2;

	double[] mag = new double[positiveSize];
	for (int i = 0; i < indexSize; i += 2) {
		mag[i / 2] = Math.sqrt(complexNumbers[i] * complexNumbers[i] + complexNumbers[i + 1] * complexNumbers[i + 1]);
	}

	return mag;
}
*/
