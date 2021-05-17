//
//  Spectrogram.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/9/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class Spectrogram {

	// private
	private let sampleRate = FingerprintProperties.sampleRate

	private var absoluteSpectrogram = [[Float]]() // absolute spectrogram
	private var spectrogram = [[Float]]()	// relative spectrogram
	private var waveData: [Int16]
	private var waveDuration: Float = 0.0

	private var fftSampleSize: Int	// number of samples in fft, the value needed to be a number to power of 2
	private var overlapFactor: Int	// 1 / overlapFactor overlapping, e.g. 1 / 4 = 25% overlapping

	// MARK: -

	init(wave: [Int16], fftSampleSize: Int, overlapFactor: Int)
	{
		waveData = wave
		waveDuration = (Float(waveData.count) / sampleRate)
		self.fftSampleSize = fftSampleSize
		self.overlapFactor = overlapFactor

		buildSpectrogram()
	}

	// MARK: -

	private func buildSpectrogram()
	{
		var amplitudes = waveData
		var numSamples = amplitudes.count

		// create the overlapping amplitude data
		if (overlapFactor > 1) {
			let numOverlappedSamples = (numSamples * overlapFactor)
			let backSamples = fftSampleSize * (overlapFactor - 1) / overlapFactor
			let fftSampleSize_1 = (fftSampleSize - 1)
			var overlapAmp = [Int16](repeating: 0, count: numOverlappedSamples)
			var pointer = 0
			var i = 0
			while (i < amplitudes.count) {
				overlapAmp[pointer] = amplitudes[i]
				pointer += 1
				if ((pointer % fftSampleSize) == fftSampleSize_1) {
					// overlap
					i -= backSamples
				}
				i += 1
			}
			numSamples = numOverlappedSamples
			amplitudes = overlapAmp
		}

/*
		// TEMP: dump for comparison testing
		print("buildSpectrogram amplitudes (\(amplitudes.count)):")
		for c in 0 ..< 5000 {
			print("\t\(c): \(amplitudes[c])")
		}
		print("")
		// ----
*/

		// number of frames of the spectrogram
		let numFrames = (numSamples / fftSampleSize)

		// TODO: Optimization: Use vDSP for the window function.

		// create the signals array for fft
		let windowFunction = WindowFunction()
		windowFunction.windowType = .hamming
		let window = windowFunction.generate(fftSampleSize)

/*
		// TEMP: dump for comparison testing
		print("buildSpectrogram window (\(window.count)):")
		let dumpCount = min(5000, window.count)
		for c in 0 ..< dumpCount {
			print("\t\(c): " + String(format: "%1.16f", window[c]))
		}
		print("")
		// ----
*/

		var signals = [[Float]](repeating: [Float](repeating: 0.0, count: fftSampleSize), count: numFrames)
		for frameIndex in 0 ..< numFrames {
			let startSample = (frameIndex * fftSampleSize)
			for n in 0 ..< fftSampleSize {
				signals[frameIndex][n] = (Float(amplitudes[startSample + n]) * window[n])
			}
		}

/*
		// TEMP: dump for comparison testing
		print("buildSpectrogram signals (\(signals.count)):")
		let dumpCount2 = min(5000, signals[42].count)
		for c in 0 ..< dumpCount2 {
			print("\t\(c): " + String(format: "%1.16f", signals[42][c]))
		}
		// ----
*/

		// TODO: Optimization: Move the FFT setup elsewhere (instead of setting up every time).

		absoluteSpectrogram = [[Float]](repeating: [Float](), count: numFrames)
		// for each frame in signals, do fft on it
		let fft = FastFourierTransform(fftSampleSize)
		for i in 0 ..< numFrames {
			absoluteSpectrogram[i] = fft.getMagnitudes(signals[i])
		}

/*
		// TEMP: dump for comparison testing
		print("buildSpectrogram absoluteSpectrogram (\(absoluteSpectrogram.count)):")
		for c in 0 ..< absoluteSpectrogram[42].count {
			print("\t\(c): " + String(format: "%1.16f", absoluteSpectrogram[42][c]))
		}
		// ----
*/

		if (absoluteSpectrogram.count > 0) {

			// number of y-axis unit
			let numFrequencyUnit = absoluteSpectrogram[0].count

			// get max and min amplitudes of the absoluteSpectrogram
			var maxAmplitude = Float.leastNormalMagnitude
			var minAmplitude = Float.greatestFiniteMagnitude
			for i in 0 ..< numFrames {
				for j in 0 ..< numFrequencyUnit {
					if (absoluteSpectrogram[i][j] > maxAmplitude) {
						maxAmplitude = absoluteSpectrogram[i][j]
					} else if (absoluteSpectrogram[i][j] < minAmplitude) {
						minAmplitude = absoluteSpectrogram[i][j]
					}
				}
			}

			// safety check the minimum amplitude to avoid divide by zero
			let minValidAmplitude: Float = 0.00000000001
			if (minAmplitude == 0.0) {
				minAmplitude = minValidAmplitude
			}

			// normalize the absolute spectrogram
			spectrogram = [[Float]](repeating: [Float](repeating: 0.0, count: numFrequencyUnit), count: numFrames)

			let diff = log10(maxAmplitude / minAmplitude)	// perceptual difference
			for i in 0 ..< numFrames {
				for j in 0 ..< numFrequencyUnit {
					if (absoluteSpectrogram[i][j] < minValidAmplitude) {
						spectrogram[i][j] = 0.0
					} else {
						spectrogram[i][j] = ((log10(absoluteSpectrogram[i][j] / minAmplitude)) / diff)
					}
				}
			}

/*
	// TEMP: dump for comparison testing
			print("buildSpectrogram spectrogram (\(spectrogram.count)):")
			for c in 0 ..< spectrogram[0].count {
				print("\t\(c): " + String(format: "%1.16f", spectrogram[0][c]))
			}
	// ----
*/

		}
	}

	func getNormalizedSpectrogramData() -> [[Float]]
	{
		return spectrogram
	}

}
