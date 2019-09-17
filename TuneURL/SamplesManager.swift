//
//  SamplesManager.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 11/13/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import Foundation


class SamplesManager: NSObject {

	static let shared = SamplesManager()

	private let samplesClient = SamplesClient()
	let cache = NSCache<Box<URL>, SampleData>()

	// MARK: -

	private override init()
	{
		super.init()
	}

	func sample(for url: URL, completion: completionHandler? = nil)
	{
		print("Requesting a sample")
		if let sample = cache.object(forKey: Box(url)) {
			print("Returning from cache")
			completion?(.success(sample))
			return
		}

		samplesClient.send(sampleUrl: url, completion: { (response) in
			defer {
				completion?(response)
			}

			switch response {
			case .success(let sampleData):
				print("Adding to cache")
				self.cache.setObject(sampleData, forKey: Box(url))
//				try? FileManager.default.removeItem(at: url)
			case .failure:
				print("Failure")
				break
			}

		})
	}

}
