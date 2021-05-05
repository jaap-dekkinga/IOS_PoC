//
//  FastFourierTransform.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#include <Accelerate/Accelerate.h>
#include <vector>

using std::vector;

class FastFourierTransform {

public:

	FastFourierTransform(int numberOfSamples);
	~FastFourierTransform();

	vector<float> getMagnitudes(const vector<float> &timeDomainData);

private:

	int fftFrameSize { 0 };

	// Accelerate opaque type that contains setup information for a given FFT transform.
	FFTSetup fftSetup { nil };

	// Accelerate type for complex number
	vector<float> complexARealP;
	vector<float> complexAImagP;

	// output data
	vector<float> outFFTData;

};
