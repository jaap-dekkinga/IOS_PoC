//
//  main.swift
//  TuneURL (CLI)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 10/27/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//


import Foundation


let arguments = CommandLine.arguments
var index = 0


while index < arguments.count {

	if (arguments[index].lowercased() == "convert") {
		// convert an audio file to the fingerprint processing format
		if ((index + 3) <= arguments.count) {
			let inputFilePath = arguments[index + 1]
			let outputFileName = arguments[index + 2]
			print("Converting audio file: '\(inputFilePath)'")
			let inputFileURL = URL(fileURLWithPath: inputFilePath)
			if let audioBuffer = AudioUtility.prepareAudioForProcessing(inputFileURL, asFloat: true) {
				let outputFileURL = inputFileURL.deletingLastPathComponent().appendingPathComponent(outputFileName)
				if (AudioUtility.writeAudioBuffer(audioBuffer, to: outputFileURL)) {
					print("File written to: \(outputFileName)")
				} else {
					print("Error writing audio file.")
				}
			}
		}
		index += 2
	} else if (arguments[index].lowercased() == "detect") {
		// detect tuneurls in an audio file
		if ((index + 3) <= arguments.count) {
			let filePath1 = arguments[index + 1]
			let filePath2 = arguments[index + 2]
			// compare the files
			print("Detecting trigger: '\(filePath1)' in: '\(filePath2)'")
			let processingSemaphore = DispatchSemaphore(value: 0)
			Detector.setTrigger(URL(fileURLWithPath: filePath1))
			Detector.processAudio(for: URL(fileURLWithPath: filePath2)) {
				responses in
				for response in responses {
					print("Response: \(response.prettyDescription())")
				}
				processingSemaphore.signal()
			}
			processingSemaphore.wait()
		}
		index += 2
	}

	index += 1
}
