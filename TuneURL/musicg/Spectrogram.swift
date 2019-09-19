//
//  Spectrogram.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/9/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class Spectrogram {

//	let sampleRate: Float = 44100.0
	let sampleRate: Float = (2048.0 * 5.0)

	private var waveData: [Int16]
	private var waveDuration: Float = 0.0
	private var spectrogram = [[Float]]()	// relative spectrogram
	private var absoluteSpectrogram = [[Float]]() // absolute spectrogram

	private var fftSampleSize: Int		// number of samples in fft, the value needed to be a number to power of 2
	private var overlapFactor: Int		// 1/overlapFactor overlapping, e.g. 1/4=25% overlapping
//	private var numFrames: Int			// number of frames of the spectrogram
//	private var framesPerSecond: Int	// frame per second of the spectrogram
//	private var numFrequencyUnit: Int	// number of y-axis unit
//	private var unitFrequency: Float	// frequency per y-axis unit

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
		var pointer = 0

		// overlapping
		if (overlapFactor > 1) {
			let numOverlappedSamples = (numSamples * overlapFactor)
			let backSamples = fftSampleSize * (overlapFactor - 1) / overlapFactor
			let fftSampleSize_1 = (fftSampleSize - 1)
			var overlapAmp = [Int16](repeating: 0, count: numOverlappedSamples)
			pointer = 0
			var i = 0
			while (i < amplitudes.count) {
				overlapAmp[pointer] = amplitudes[i]
				pointer += 1
				if (pointer % fftSampleSize == fftSampleSize_1) {
					// overlap
					i -= backSamples
				}
				i += 1
			}
			numSamples = numOverlappedSamples
			amplitudes = overlapAmp
		}
		// end overlapping
/*
		// TEMP: dump for comparison testing
		print("buildSpectrogram amplitudes (\(amplitudes.count)):")
		for c in 0 ..< 5000 {
			print("\t\(c): \(amplitudes[c])")
		}
		// ----
*/
		let numFrames = (numSamples / fftSampleSize)
		let framesPerSecond = Int(Float(numFrames) / waveDuration)

		// set signals for fft
		let window = WindowFunction()
		window.windowType = .hamming
		let win = window.generate(fftSampleSize)

//		double[][] signals=new double[numFrames][]
		var signals = [[Float]](repeating: [Float](), count: numFrames)
		for f in 0 ..< numFrames {
			var array = [Float](repeating: 0.0, count: fftSampleSize)
//			signals[f] = [Float](repeating: 0.0, count: fftSampleSize)
			let startSample = f * fftSampleSize
			for n in 0 ..< fftSampleSize {
//				signals[f][n] = amplitudes[startSample + n] * win[n]
				array[n] = Float(amplitudes[startSample + n]) * win[n]
			}
			signals[f] = array
		}
		// end set signals for fft
/*
		// TEMP: dump for comparison testing
		print("buildSpectrogram signals (\(signals.count)):")
		for c in 0 ..< signals[42].count {
			print("\t\(c): " + String(format: "%1.16f", signals[42][c]))
		}
		// ----
*/
		// TODO: move the FFT setup to initialization elsewhere (instead of every time)

//		absoluteSpectrogram = new double[numFrames][]
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

			let numFrequencyUnit = absoluteSpectrogram[0].count
			let unitFrequency = sampleRate / 2.0 / Float(numFrequencyUnit)
			// Note: frequency could be caught within the half of nSamples according to Nyquist theory

			// get max and min amplitudes of the absoluteSpectrogram
			var maxAmp = Float.leastNormalMagnitude
			var minAmp = Float.greatestFiniteMagnitude
			for i in 0 ..< numFrames {
				for j in 0 ..< numFrequencyUnit {
					if (absoluteSpectrogram[i][j] > maxAmp) {
						maxAmp = absoluteSpectrogram[i][j]
					} else if (absoluteSpectrogram[i][j] < minAmp) {
						minAmp = absoluteSpectrogram[i][j]
					}
				}
			}
			// end set max and min amplitudes

			// normalization
			// avoid divide by zero
			let minValidAmp: Float = 0.00000000001
			if (minAmp == 0.0) {
				minAmp = minValidAmp
			}

			// normalization of absoluteSpectrogram
//			spectrogram = new double[numFrames][numFrequencyUnit]
			spectrogram = [[Float]](repeating: [Float](repeating: 0.0, count: numFrequencyUnit), count: numFrames)

			let diff = log10(maxAmp / minAmp)	// perceptual difference
			for i in 0 ..< numFrames {
				for j in 0 ..< numFrequencyUnit {
					if (absoluteSpectrogram[i][j] < minValidAmp) {
						spectrogram[i][j] = 0
					} else {
						spectrogram[i][j] = (log10(absoluteSpectrogram[i][j] / minAmp)) / diff
					}
				}
			}
			// end normalization
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
/*
	public double[][] getAbsoluteSpectrogramData(){
	return absoluteSpectrogram
	}

	public int getNumFrames(){
	return numFrames
	}

	public int getFramesPerSecond(){
	return framesPerSecond
	}

	public int getNumFrequencyUnit(){
	return numFrequencyUnit
	}

	public double getUnitFrequency(){
	return unitFrequency
	}

	public int getFftSampleSize() {
	return fftSampleSize
	}

	public int getOverlapFactor() {
	return overlapFactor
	}
*/
}
