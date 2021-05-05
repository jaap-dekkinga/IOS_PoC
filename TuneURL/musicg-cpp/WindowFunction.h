//
//  WindowFunction.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//


#include <vector>

using std::vector;

enum WindowFunctionType {
	rectangular,
	bartlett,
	hanning,
	hamming,
	blackman
};

class WindowFunction {

public:

	// defaults to rectangular window
	WindowFunctionType windowType { WindowFunctionType::rectangular };

	vector<float> generate(int nSamples);

};
