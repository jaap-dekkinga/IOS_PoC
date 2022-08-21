//
//  Reporting.swift
//  TuneURL (SDK)
//
//  Created by Jaap Dekkinga.
//  Copyright © 2020-2022 TuneURL Inc. All rights reserved.
//


import Foundation


public class Reporting {

	public enum Action: String {
		case heard = "heard"
		case interested = "interested"
		case acted = "acted"
		case shared = "shared"
	}

	public static var shared = Reporting()

	// Reporting server configuration
	private let serverHost = "65neejq3c9.execute-api.us-east-2.amazonaws.com/"
	private let serverPath = "interests"

	// MARK: - Public

	public func report(action: Action, for match: Match, userID: String? = nil)
	{
		// create the reporting data
		let reportingData = ReportingData(action: action, tuneURLID: match.id, userID: userID)

		// send the report
		self.send(reports: [reportingData]) {
			_ in
		}
	}

	// MARK: - Private

	private func send(reports: [ReportingData], completion: @escaping (_ response: ReportingResponse?) -> ())
	{
		// create the report server url
		guard let serverURL = URL(string: ("https://" + serverHost + serverPath)) else {
			return
		}

		// convert the reports to json data
		guard let jsonData = try? JSONSerialization.data(withJSONObject: reports, options: .prettyPrinted) else {
			return
		}

		let url = serverURL
		var request = URLRequest(url: url)
		request.timeoutInterval = 60.0
		request.httpMethod = "POST"
		request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
		request.httpBody = jsonData
/*
 //		let userId = reportingData.userID.replacingOccurrences(of: "-", with: "")
		"[\n{\n\"UserID\":\"\(userId)\",\n\"Date\":\"\(reportingData.timestampString)\",\n\"TuneURL_ID\":\"\(reportingData.TuneURL_ID)\",\n\"Interest_action\":\"\(reportingData.Interest_action)\"\n }\n]"
				.data(using: .utf8)
*/
		let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
