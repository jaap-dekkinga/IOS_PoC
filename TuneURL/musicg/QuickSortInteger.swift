//
//  QuickSortInteger.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class QuickSortInteger {

	private var indexes: [Int]
	private var array: [Int]

	init(_ array: [Int])
	{
		self.array = array
		indexes = [Int](repeating: 0, count: array.count)
		for i in 0 ..< indexes.count {
			indexes[i] = i
		}
	}

	func getSortIndexes() -> [Int]
	{
		sort()
		return indexes
	}

	private func sort()
	{
		quicksort(0, indexes.count - 1)
	}

	// quicksort a[left] to a[right]
	private func quicksort(_ left: Int, _ right: Int)
	{
		if (right <= left) {
			return
		}

		let i = partition(left, right)
		quicksort(left, i - 1)
		quicksort(i + 1, right)
	}

	// partition a[left] to a[right], assumes left < right
	private func partition(_ left: Int, _ right: Int) -> Int
	{
		var i = left - 1
		var j = right

		while (true) {
			// find item on left to swap, a[right] acts as sentinel

//			while (array[indexes[++i]] < array[indexes[right]]);
			repeat {
				i += 1
			} while (array[indexes[i]] < array[indexes[right]])

			// find item on right to swap
//			while (array[indexes[right]] < array[indexes[--j]]) {
			while (true) {
				j -= 1
				if (!(array[indexes[right]] < array[indexes[j]])) {
					break
				}

				if (j == left) {
					// don't go out-of-bounds
					break
				}
			}

			// check if pointers cross
			if (i >= j) {
				break
			}

			// swap two elements into place
			swap(i, j)
		}

		// swap with partition element
		swap(i, right)

		return i
	}

	// exchange a[i] and a[j]
	private func swap(_ i: Int, _ j: Int)
	{
		let swap = indexes[i]
		indexes[i] = indexes[j]
		indexes[j] = swap
	}

}
