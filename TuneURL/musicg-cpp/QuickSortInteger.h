//
//  QuickSortInteger.h
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 5/4/21.
//  Copyright (c) 2021 TuneURL Inc. All rights reserved.
//

#include <vector>

using std::vector;

class QuickSortInteger {

private:

	vector<int> array;
	vector<int> indexes;

public:

	QuickSortInteger(const vector<int> &array);

	vector<int> getSortIndexes();

private:

	void quicksort(int left, int right);
	int partition(int left, int right);
	void swap(int i, int j);

};
