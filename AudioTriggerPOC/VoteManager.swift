//
//  VoteManager.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-06-10.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation

class VoteManager: NSObject {
    fileprivate let samplesClient = SamplesClient()
    fileprivate let pollClient = PollClient()
    fileprivate let sampleDataManager = SampleDataManager()

    func castVote(userResponse: Bool, for sampleUrl: URL) {
        samplesClient.send(sampleUrl: sampleUrl, completion: { (response) in
            defer {
                try? FileManager.default.removeItem(at: sampleUrl)
            }

            self.sampleDataManager.add(response)

            let pollData = PollData(response: userResponse,
                                    name: response.title)
            self.pollClient.postVote(pollData: pollData)
        })
    }
}
