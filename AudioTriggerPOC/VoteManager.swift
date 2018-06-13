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

            let pollData = PollData(response: userResponse,
                                    name: response.title)
            self.pollClient.postVote(pollData: pollData, completion: { (pollDataResponse) in

                //TODO: See if there will be the need for this in the future
                // if yes, refactor, if no delete
                var augmentedResponse = response
                switch response {
                case .success(let sampleData):
                    sampleData.pollDataResponse = pollDataResponse
                    augmentedResponse = SampleResult.success(sampleData)
                case .failure(_):
                    augmentedResponse = response
                }
                self.sampleDataManager.add(augmentedResponse)
            })
        })
    }
}
