//
//  SamplesManager.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-11-13.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation

class SamplesManager: NSObject {
    static let shared = SamplesManager()
    private override init() {
        super.init()
    }

    private let samplesClient = SamplesClient()
    let cache = NSCache<Box<URL>, SampleData>()

    func sample(for url: URL, completion: completionHandler? = nil) {
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
//                try? FileManager.default.removeItem(at: url)
            case .failure:
                print("Failure")
                break
            }

        })
    }

}
