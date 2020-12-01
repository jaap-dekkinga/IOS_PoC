//
//  ReportingManager.swift
//  TuneURL
//
//  Created by Jaap Dekkinga.
//  Copyright © 2020-2021 TuneURL Inc. All rights reserved.
//


import Alamofire
import Foundation


class ReportingManager: NSObject {

	// Reporting server configuration
	private let serverHost = "65neejq3c9.execute-api.us-east-2.amazonaws.com"
	private let serverPath = "interests"

	// MARK: -

    func captureUserAction(for matchedItem: MatchedItem, InterestAction: String)
	{
		// get the songId
        let matchedTime = matchedItem.matchedTime
        let uuid = matchedItem.uuid
        let songId = matchedItem.songId
		// create the reporting data
        let reportingData = ReportingData (UserId: InterestAction, TuneURL_ID: songId!, Interest_action: uuid, timestamp: matchedTime)

		// post the reporting record
		self.postReporting(reportingData: reportingData, completion: {
			(reportingResponse: ReportingResponse?) in

			// TODO: mark the item as having been voted on
			// TODO: act on the server response?

//			print("reportingResponse: \(reportingResponse)")

		})
	}

	// MARK: -
	// MARK: Private

	private func postReporting(reportingData: ReportingData, completion: @escaping (_ response2: ReportingResponse?) -> ())
	{
		// create the poll server url
		guard let serverURL = URL(string: ("https://" + serverHost + serverPath)) else {
			return
		}

		// perform the vote post request
		Alamofire.request(serverURL, method: .post, parameters: reportingData.parameters, encoding: JSONEncoding.default).response {
			(response) in

			// get the response data
			guard let response2Data = response.data else {
				completion(nil)
				return
			}

			// parse the json response
            let reportingResponse = try?  JSONDecoder().decode(ReportingResponse.self, from: response2Data)

			// call the completion handler
			completion(reportingResponse)
		}
	}

}
