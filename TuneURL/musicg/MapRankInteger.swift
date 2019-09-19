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

	public func getOrderedKeyList(_ numKeys1: Int, _ sharpLimit: Bool) -> [Int]
	{
		// if sharp limited, will return sharp numKeys, otherwise will return until the values not equals the exact key's value

//		Set mapEntrySet = map.entrySet()
		let mapEntrySet = map.values
//		var keyList = new LinkedList()
		var keyList = [Int]()
		var numKeys = numKeys1

		// if the numKeys is larger than map size, limit it
		if (numKeys > map.count) {
			numKeys = map.count
		}
		// end if the numKeys is larger than map size, limit it

		if (map.count > 0) {
//			var array = [Int](repeating: 0, count: map.count)
			var count = 0

			// get the pass values
//			Iterator<Entry> mapIterator = mapEntrySet.iterator();
//			while (mapIterator.hasNext()) {
//				Entry entry = mapIterator.next();
			for entry in mapEntrySet {
//				array[count++] = (Integer)entry.getValue();
				array[count] = entry
				count += 1
			}
			// end get the pass values

			var targetindex: Int
			if (ascending) {
				targetindex = numKeys
			} else {
				targetindex = array.count - numKeys
			}

			let passValue = getOrderedValue(targetindex)	// this value is the value of the numKey-th element
			// get the passed keys and values
//			Map passedMap = new HashMap()
			var passedMap = [Int : Int]()
//			List<Integer> valueList = new LinkedList<Integer>()
			var valueList = [Int]()

//			mapIterator = mapEntrySet.iterator()
//			while (mapIterator.hasNext()){
//				Entry entry=mapIterator.next();
			for (entryKey, value) in map {

//				int value=(Integer)entry.getValue();

				if ((ascending && value <= passValue) || (!ascending && value >= passValue)) {
//					passedMap.put(entry.getKey(), value);
					passedMap[entryKey] = value
					valueList.append(value)
				}
			}
			// end get the passed keys and values

			// sort the value list
//			Integer[] listArr = new Integer[valueList.count]
//			valueList.toArray(listArr)
			var listArr = valueList
//			Arrays.sort(listArr);
			listArr.sort()
			// end sort the value list

			// get the list of keys
			var resultCount = 0
			var index: Int
			if (ascending){
				index = 0
			} else {
				index = listArr.count - 1
			}

			if (!sharpLimit) {
				numKeys = listArr.count
			}

			while (true) {
				let targetValue = listArr[index]
//				Iterator<Entry> passedMapIterator = passedMap.entrySet().iterator();
//				while(passedMapIterator.hasNext()) {
//					Entry entry=passedMapIterator.next()
				for (entryKey, entryValue) in passedMap {
//					if ((Integer)entry.getValue()==targetValue) {
					if (entryValue == targetValue) {
//						keyList.append(entry.getKey())
						keyList.append(entryKey)
//						passedMapIterator.remove()
						passedMap.removeValue(forKey: entryKey)
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
			// end get the list of keys
		}

		return keyList
	}

	private func getOrderedValue(_ index: Int) -> Int
	{
		locate(0, array.count - 1, index)
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
				locate(left, i - 1, index)
			} else {
				// the target index in the right partition
				locate(j + 1, right, index)
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
