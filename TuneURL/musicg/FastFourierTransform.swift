//
//  FastFourierTransform.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/9/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Accelerate
import Foundation


class FastFourierTransform {

	let fftFrameSize: Int

	// Accelerate opaque type that contains setup information for a given FFT transform.
	var fftSetup: FFTSetup?

	// Accelerate type for complex number
	var complexARealP: [Float]
	var complexAImagP: [Float]

	// Your fft output data
	var outFFTData: [Float]

	// MARK: -

	init(_ numberOfSamples: Int)
	{
		fftFrameSize = (numberOfSamples / 2)

		let log2n = vDSP_Length(log2f(Float(fftFrameSize)))

		complexARealP = [Float](repeating: 0.0, count: fftFrameSize)
		complexAImagP = [Float](repeating: 0.0, count: fftFrameSize)
		outFFTData = [Float](repeating: 0.0, count: (fftFrameSize / 2))

		fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2))
	}

	deinit
	{
		if fftSetup != nil {
			vDSP_destroy_fftsetup(fftSetup!)
			fftSetup = nil
		}
	}

	func getMagnitudes(_ timeDomainData: [Float]) -> [Float]
	{
		// safety check
		guard let setup = fftSetup else {
			return outFFTData
		}

		let log2n = vDSP_Length(log2f(Float(fftFrameSize)))

		timeDomainData.withUnsafeBufferPointer {
			timeDomainDataBufferPointer in

			let timeDomainDataPointer = timeDomainDataBufferPointer.baseAddress!
			let timeDomainPointer = unsafeBitCast(timeDomainDataPointer, to: UnsafePointer<DSPComplex>.self)

			complexARealP.withUnsafeMutableBufferPointer {
				realPBufferPointer in

				complexAImagP.withUnsafeMutableBufferPointer {
					imagPBufferPointer in

					var complexA = COMPLEX_SPLIT(realp: realPBufferPointer.baseAddress!, imagp: imagPBufferPointer.baseAddress!)
//					complexA.realp = realPBufferPointer.baseAddress!
//					complexA.imagp = imagPBufferPointer.baseAddress!

					// Convert float array of reals samples to COMPLEX_SPLIT array A

					// Copies the contents of an interleaved complex vector C to a split complex vector Z; single precision.
					vDSP_ctoz(timeDomainPointer, 2, &complexA, 1, vDSP_Length(fftFrameSize))

					// Perform FFT using fftSetup and A
					// Results are returned in A

					// Computes an in-place single-precision real discrete Fourier transform, either from the time domain to the frequency domain (forward) or from the frequency domain to the time domain (inverse).
//					vDSP_fft_zrip(setup, &complexA, 1, log2n, FFTDirection(FFT_FORWARD))
					vDSP_fft_zip(setup, &complexA, 1, log2n, FFTDirection(FFT_FORWARD))

					// scale fft
					// Single-precision real vector-scalar multiply.
//					vDSP_vsmul(complexA.realp, 1, &mFFTNormFactor, complexA.realp, 1, fftFrameSize)
//					vDSP_vsmul(complexA.imagp, 1, &mFFTNormFactor, complexA.imagp, 1, fftFrameSize)
/*
					outFFTData.withUnsafeMutableBufferPointer {
						outFFTDataBufferPointer in

						let outDataPointer = outFFTDataBufferPointer.baseAddress!

						// Complex vector magnitudes squared; single precision.
						vDSP_zvmags(&complexA, 1, outDataPointer, 1, fftFrameSize)
					}
*/
					//to check everything =============================
//					vDSP_fft_zrip(setup, &complexA, 1, log2n, FFTDirection(FFT_INVERSE))
//					vDSP_ztoc(&complexA, 1, (COMPLEX*)invertedCheckData , 2, (numSamples / 2))
					//=================================================
				}
			}
		}

		// TODO: perform this step with vDSP

		for c in 0 ..< outFFTData.count {
			let value = (complexARealP[c] * complexARealP[c]) + (complexAImagP[c] * complexAImagP[c])
			outFFTData[c] = sqrt(value)
		}

		return outFFTData
	}
/*
	func getMagnitudes(_ amplitudes: [Float]) -> [Float]
	{
		let sampleSize = amplitudes.count

		// call the fft and transform the complex numbers
		FFT fft = new FFT(sampleSize / 2, -1);
		fft.transform(amplitudes);
		// end call the fft and transform the complex numbers

		double[] complexNumbers = amplitudes;

		// even indexes (0,2,4,6,...) are real parts
		// odd indexes (1,3,5,7,...) are img parts
		int indexSize = sampleSize / 2

		// FFT produces a transformed pair of arrays where the first half of the
		// values represent positive frequency components and the second half
		// represents negative frequency components.
		// we omit the negative ones
		int positiveSize = indexSize / 2

		double[] mag = new double[positiveSize]
		for (int i = 0; i < indexSize; i += 2) {
			mag[i / 2] = Math.sqrt(complexNumbers[i] * complexNumbers[i] + complexNumbers[i + 1] * complexNumbers[i + 1])
		}

		return mag
	}
*/
}
