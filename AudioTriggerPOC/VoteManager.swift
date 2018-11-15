//
//  VoteManager.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-06-10.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation
import UIKit.UIApplication

class VoteManager: NSObject {
    fileprivate let samplesClient = SamplesClient()
    fileprivate let pollClient = PollClient()
    fileprivate let sampleDataManager = SampleDataManager()

    func castVote(userResponse: Bool, for sampleUrl: URL) {
        print("Cast Vote")
        SamplesManager.shared.sample(for: sampleUrl) { (response) in
            defer {
                try? FileManager.default.removeItem(at: sampleUrl)
            }

            if response.desc == "open_page" {
                switch userResponse {
                case true:
                    if let urlString = response.url, let url = URL(string: urlString) {
                        UIApplication.shared.open(url, completionHandler: { (success) in
                            print((success ? "Page openned" : "Error opening page")
                                + ": "
                                +  urlString)
                        })
                    }
                case false:
                    print("User decided not to open page")
                    break
                }
                return
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
        }
    }
}

private extension SampleResult {
    var title: String {
        switch self {
        case .success(let value):
            return value.title
        case .failure(_):
            return "unknown"
        }
    }

    var desc: String {
        switch self {
        case .success(let value):
            return value.desc
        case .failure(let error):
            return error.desc
        }
    }

    var url: String? {
        switch self {
        case .success(let value):
            return value.url
        case .failure:
            return nil
        }
    }

    func prettyDescription() -> String {
        switch self {
        case .success(let value):
            return value.prettyDescription()
        case .failure(let error):
            return "error: " + error.desc + " " + String(error.code)
        }
    }
}
