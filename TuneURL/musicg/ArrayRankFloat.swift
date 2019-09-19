//
//  ArrayRankFloat.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/10/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class ArrayRankFloat {

	// private
	private var array: [Float]

	// MARK: -

	init(array: [Float])
	{
		self.array = array
	}

	// MARK: -

	func getNthOrderedValue(n: Int, ascending: Bool) -> Float
	{
		var targetIndex = n

		if (targetIndex > array.count) {
			targetIndex = array.count
		}

		if (ascending == false) {
			targetIndex = (array.count - targetIndex)
		}

		// this value is the value of the numKey-th element
		let passValue = getOrderedValue(index: targetIndex)

		return passValue
	}

	// MARK: -
	// MARK: Private

	private func getOrderedValue(index: Int) -> Float
	{
		locate(left: 0, right: (array.count - 1), index: index)
		return array[index]
	}

	// sort the partitions by quick sort, and locate the target index
	private func locate(left: Int, right: Int, index: Int)
	{
		if (right == left) {
			return
		}

		if (left < right) {
			let mid = ((left + right) / 2)
			let s = array[mid]
			var i = (left - 1)
			var j = (right + 1)

			while (true) {
				repeat {
					i += 1
				} while (array[i] < s)

				repeat {
					j -= 1
				} while (array[j] > s)

				if (i >= j) {
					break
				}

				swap(i, j)
			}

			if (i > index) {
				// the target index in the left partition
				locate(left: left, right: (i - 1), index: index)
			} else {
				// the target index in the right partition
				locate(left: (j + 1), right: right, index: index)
			}
		}
	}

	private func swap(_ i: Int, _ j: Int)
	{
		let t = array[i]
		array[i] = array[j]
		array[j] = t
	}

}
