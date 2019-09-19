//
//  WindowFunction.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/9/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


enum WindowFunctionTypes {

	case rectangular
	case bartlett
	case hanning
	case hamming
	case blackman

}


class WindowFunction {

	// defaults to rectangular window
	var windowType = WindowFunctionTypes.rectangular

	// MARK: -

	func generate(_ nSamples: Int) -> [Float]
	{
		// generate nSamples window function values
		// for index values 0 .. nSamples - 1
		let mInt = (nSamples / 2)
		let m = Float(mInt)
		let pi = Float.pi
		var w = [Float](repeating: 0.0, count: nSamples)

		switch (windowType) {
			case .bartlett: // Bartlett (triangular) window
				for n in 0 ..< nSamples {
					w[n] = 1.0 - abs(Float(n) - m) / m
				}

			case .hanning: // Hanning window
				let r = (pi / (m + 1))
				var n = -mInt
				while (n < mInt) {
					w[mInt + n] = 0.5 + 0.5 * cos(Float(n) * r)
					n += 1
				}

			case .hamming: // Hamming window
				let r = (pi / m)
				var n = -mInt
				while (n < mInt) {
					w[mInt + n] = 0.54 + 0.46 * cos(Float(n) * r)
					n += 1
				}

			case .blackman: // Blackman window
				let r = (pi / m)
				var n = -mInt
				while (n < mInt) {
					w[mInt + n] = 0.42 + 0.5 * cos(Float(n) * r) + 0.08 * cos(2 * Float(n) * r)
					n += 1
				}

			default: // Rectangular window function
				for n in 0 ..< nSamples {
					w[n] = 1.0
				}
		}

		return w
	}

}
