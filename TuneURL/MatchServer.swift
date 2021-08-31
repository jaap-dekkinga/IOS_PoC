//
//  MatchServer.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/23/19.
//  Copyright © 2018-2021 TuneURL Inc. All rights reserved.
//


import Alamofire
import Foundation


class MatchServer {

	// static
	static let shared = MatchServer()

	// match server configuration
	private let serverHost = "pnz3vadc52.execute-api.us-east-2.amazonaws.com"
	private let serverMatchPath = "/dev/search-fingerprint"

	// MARK: -

	func requestMatch(for fingerprintData: [UInt8], completion: ((MatchResponse?) -> Void)? = nil)
	{
#if DEBUG
		print("Requesting fingerprint match.")
#endif // DEBUG

		// create the server url
		guard let serverURL = URL(string: ("https://" + serverHost + serverMatchPath)) else {
			return
		}

		// create the request parameters
		let fingerprintParameters: [String : Any] = [
			"type" : "buffer",
			"data" : fingerprintData
		]
		let parameters = [
			"fingerprint" : fingerprintParameters
		]

		// make the request
		Alamofire.request(serverURL, method: .post, parameters: parameters, encoding: JSONEncoding.default).response {
			(response) in

			// get the response data
			guard let responseData = response.data else {
				completion?(nil)
				return
			}

#if DEBUG
			print("Match response: \(String(data: responseData, encoding: .utf8) ?? "")")
#endif // DEBUG

			// parse the response
			var matchResponse: MatchResponse?
			if let matchResponses = try? JSONDecoder().decode([MatchResponse].self, from: responseData) {
				// find the best match response
				var bestPercentage = -1
				for item in matchResponses {
					if (item.matchPercentage > bestPercentage) {
						bestPercentage = item.matchPercentage
						matchResponse = item
					}
				}
			}

			// call the completion handler
			completion?(matchResponse)
		}
	}

}
