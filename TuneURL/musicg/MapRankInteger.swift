//
//  MapRankInteger.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/11/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class MapRankInteger {

	// private
	private var map: [Int : Int]
	private var array: [Int]
	private var ascending = true

	// MARK: -

	init(_ map: [Int : Int], ascending: Bool)
	{
		self.map = map
		self.ascending = ascending

		array = [Int](repeating: 0, count: map.count)
	}

	func getOrderedKeyList(_ numKeys1: Int, _ sharpLimit: Bool) -> [Int]
	{
		// if sharp limited, will return sharp numKeys, otherwise will return until the values not equals the exact key's value

		var keyList = [Int]()
		var numKeys = numKeys1

		// if the numKeys is larger than map size, limit it
		if (numKeys > map.count) {
			numKeys = map.count
		}

		if (map.count > 0) {
//			var array = [Int](repeating: 0, count: map.count)
			var count = 0

			// get the pass values
			for value in map.values {
				array[count] = value
				count += 1
			}

			var targetindex: Int
			if (ascending) {
				targetindex = numKeys
			} else {
				targetindex = (array.count - numKeys)
			}

			// get the passed keys and values
			let passValue = getOrderedValue(targetindex)	// this value is the value of the numKey-th element
			var passedMap = [Int : Int]()
			var valueList = [Int]()

			for (key, value) in map {
				if ((ascending && (value <= passValue)) || (!ascending && (value >= passValue))) {
					passedMap[key] = value
					valueList.append(value)
				}
			}

			// sort the value list
            let sortedValueList = valueList.sorted()

			// get the list of keys
			var resultCount = 0
			var index: Int

			if (ascending) {
				index = 0
			} else {
				index = (sortedValueList.count - 1)
			}

			if (!sharpLimit) {
				numKeys = sortedValueList.count
			}

			while (true) {
				let targetValue = sortedValueList[index]

				for (key, value) in passedMap {
					if (value == targetValue) {
						keyList.append(key)
						passedMap.removeValue(forKey: key)
						resultCount += 1
						break
					}
				}

				if (ascending) {
					index += 1
				} else {
					index -= 1
				}

				if (resultCount >= numKeys) {
					break
				}
			}
		}

		return keyList
	}

	// MARK: -
	// MARK: Private

	private func getOrderedValue(_ index: Int) -> Int
	{
		locate(0, (array.count - 1), index)
		return array[index]
	}

	// sort the partitions by quick sort, and locate the target index
	private func locate(_ left: Int, _ right: Int, _ index: Int)
	{
		let mid = ((left + right) / 2)

		if (right == left) {
			return
		}

		if (left < right) {
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
				locate(left, (i - 1), index)
			} else {
				// the target index in the right partition
				locate((j + 1), right, index)
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
