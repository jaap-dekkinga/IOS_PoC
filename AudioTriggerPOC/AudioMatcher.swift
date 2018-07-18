//
//  AudioMatcher.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-18.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation
import RunACRSDK

protocol AudioMatcherDelegate {
    func foundMatch(_ matcher: AudioMatcher)
}

class AudioMatcher: NSObject {
    private let runAcr: RunACR
    var enabled: Bool = true {
        didSet {
            if enabled {
                self.start()
            }
        }
    }
    var delegate: AudioMatcherDelegate?

    init(runAcr: RunACR, apiKey: String, sampleDataPath: String) {
        self.runAcr = runAcr
        super.init()

        self.runAcr.initialize(withAPIKey: apiKey)
        self.runAcr.updateDatabasePath(sampleDataPath)
        self.runAcr.delegate = self
    }

    func start() {
        DispatchQueue.main.async {
            self.runAcr.startRecognize()
            print("startRecognize")
        }
    }
}

extension AudioMatcher: RunACRDelegate {
    func didRecognize(_ trackId: Int32, absoluteTimeOffset: Float, relativeTimeOffset: Float) {
        print("did Recognize")
        if self.enabled {
            delegate?.foundMatch(self)
            self.runAcr.startRecognize()
        }
    }

    func didNotRecognize() {
        print("did Not Recognize")
        if self.enabled {
            self.runAcr.startRecognize()
        }
    }
}
