//
//  PollClient.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-06-08.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Alamofire

class PollData: NSObject {
    let response: Bool
    let name: String
    let timestamp: Date

    var responseString: String {
        return response ? "yes" : "no"
    }
    var timestampString: String {
        return timestamp.description
    }

    init(response: Bool, name: String, timestamp: Date = Date()) {
        self.response = response
        self.name = name
        self.timestamp = timestamp
    }
}

extension PollData: Encodable {
    private enum CodingKeys: String, CodingKey {
        case response = "Response"
        case name = "Name"
        case responseTime = "ResponseTime"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(responseString, forKey: CodingKeys.response)
        try container.encode(name, forKey: CodingKeys.name)
        try container.encode(timestampString, forKey: CodingKeys.responseTime)
    }
}

class PollClient: NSObject {
    private let host = "pollapiwebservice.us-east-2.elasticbeanstalk.com"
    private let path = "/api/pollapi"
    private var url: String {
        return "http://" + host + path
    }

    func postVote(pollData: PollData) {
        let url = URL(string: self.url)!
        Alamofire.request(url, method: .post,
                          parameters: pollData.parameters,
                          encoding: JSONEncoding.default)
    }

}
