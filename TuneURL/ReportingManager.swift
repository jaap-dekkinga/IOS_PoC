//
//  ReportingManager.swift
//  TuneURL
//
//  Created by Jaap Dekkinga.
//  Copyright © 2020-2022 TuneURL Inc. All rights reserved.
//


import Alamofire
import Foundation


class ReportingManager {

	// Reporting server configuration
	private let serverHost = "65neejq3c9.execute-api.us-east-2.amazonaws.com/"
	private let serverPath = "interests"

	// MARK: -

	func captureUserAction(for matchedItem: MatchedItem, interestAction: String)
	{
		// get the tuneurl id
		let matchedTime = matchedItem.matchedTime
		let uuid = matchedItem.uuid
		let id = matchedItem.id
		let idString = "\(id!)"

		// create the reporting data
		let reportingData = ReportingData(UserId: uuid, TuneURL_ID: idString, Interest_action: interestAction, timestamp: matchedTime)

		// post the reporting record
		self.postReporting(reportingData: reportingData, completion: {
			(reportingResponse: ReportingResponse?) in
			print(reportingResponse as Any)
			// TODO: mark the item as having been voted on
			// TODO: act on the server response?

//			print("reportingResponse: \(reportingResponse)")
		})
	}

	// MARK: - Private

	private func postReporting(reportingData: ReportingData, completion: @escaping (_ response2: ReportingResponse?) -> ())
	{
		// create the poll server url
		guard let serverURL = URL(string: ("https://" + serverHost + serverPath)) else {
			return
		}

		let url = serverURL
		var request2 = URLRequest(url: url)
		request2.httpMethod = "POST"
		request2.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let userId = reportingData.UserId.replacingOccurrences(of: "-", with: "")

		request2.httpBody = "[\n{\n\"UserID\":\"\(userId)\",\n\"Date\":\"\(reportingData.timestampString)\",\n\"TuneURL_ID\":\"\(reportingData.TuneURL_ID)\",\n\"Interest_action\":\"\(reportingData.Interest_action)\"\n }\n]"
				.data(using: .utf8)

		let task = URLSession.shared.dataTask(with: request2) { data, response, error in
			if let response = response {
				debugPrint("HTTP Response: ", response)

				if let data = data, let body = String(data: data, encoding: .utf8) {
					print("Body: ", body)
				}
			} else {
				print(error ?? "Unknown error")
			}
		}

		task.resume()
	}

}
