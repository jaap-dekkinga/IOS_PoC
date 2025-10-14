//
//  PollManager.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 6/10/18.
//  Copyright © 2018-2022 TuneURL Inc. All rights reserved.
//


import Alamofire
import Foundation


class PollManager: NSObject {

	// poll server configuration
	private let serverHost = "pollapiwebservice.us-east-2.elasticbeanstalk.com"
	private let serverPath = "/api/pollapi"

	// MARK: -

	func castVote(userResponse: Bool, for matchedItem: MatchedItem)
	{
		// get the poll id
		guard let pollID = matchedItem.pollID else {
			return
		}

		// create the poll data
		let pollData = PollData(response: userResponse, name: pollID)

		// post the vote
		self.postVote(pollData: pollData, completion: {
			(pollResponse: PollResponse?) in

			// TODO: mark the item as having been voted on
			// TODO: act on the server response?

//			print("pollResponse: \(pollResponse)")

		})
	}

	// MARK: - Private

	private func postVote(pollData: PollData, completion: @escaping (_ response: PollResponse?) -> ())
	{
		// create the poll server url
		guard let serverURL = URL(string: ("http://" + serverHost + serverPath)) else {
			return
		}

		// perform the vote post request
        Session.default.request(serverURL, method: .post, parameters: pollData.parameters, encoding: JSONEncoding.default).response {
			(response) in

			// get the response data
			guard let responseData = response.data else {
				completion(nil)
				return
			}

			// parse the json response
			let pollResponse = try? JSONDecoder().decode(PollResponse.self, from: responseData)

			// call the completion handler
			completion(pollResponse)
		}
	}

}
