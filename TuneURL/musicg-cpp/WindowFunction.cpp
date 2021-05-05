//
//  WindowFunction.cpp
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//


#include <math.h>
#include "WindowFunction.h"


vector<float> WindowFunction::generate(int nSamples)
{
	// generate nSamples window function values
	// for index values 0 .. nSamples - 1
	int mInt = (nSamples / 2);
	float m = (float)mInt;
	float pi = M_PI;
	vector<float> w = vector<float>(nSamples);

	switch (windowType) {
		case WindowFunctionType::bartlett: // Bartlett (triangular) window
			for (int n = 0; n < nSamples; n++) {
				w[n] = 1.0f - fabsf((float)n - m) / m;
			}
			break;

		case WindowFunctionType::hanning: // Hanning window
		{
			float r = (pi / (m + 1.0f));
			int n = -mInt;
			while (n < mInt) {
				w[mInt + n] = 0.5f + 0.5f * cosf((float)n * r);
				n += 1;
			}
			break;
		}

		case WindowFunctionType::hamming: // Hamming window
		{
			float r = (pi / m);
			int n = -mInt;
			while (n < mInt) {
				w[mInt + n] = 0.54f + 0.46f * cosf((float)n * r);
				n += 1;
			}
			break;
		}

		case WindowFunctionType::blackman: // Blackman window
		{
			float r = (pi / m);
			int n = -mInt;
			while (n < mInt) {
				w[mInt + n] = 0.42f + 0.5f * cosf((float)n * r) + 0.08f * cosf(2.0f * (float)n * r);
				n += 1;
			}
			break;
		}

		default: // Rectangular window function
			for (int n = 0; n < nSamples; n++) {
				w[n] = 1.0f;
			}
			break;
	}

	return w;
}
