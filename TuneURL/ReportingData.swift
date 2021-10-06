//
//  ReportingData.swift
//  TuneURL
//
//  Created by Jaap Dekkinga.
//  Copyright © 2020-2021 TuneURL Inc. All rights reserved.
//


import Foundation


struct ReportingResponse: Codable {

	struct ReportingItem: Codable {

		let status: String
		let message: String

		func prettyDescription() -> String {
			return "\n"
				+ "status: " + status + "\n"
				+ "message: " + message + "\n"
				+ "\n"
		}

	}

	let value: [ReportingItem]
	let statusCode: Int
}

class ReportingData {

	let UserId: String
	let Interest_action: String
	let TuneURL_ID: String
	let timestamp: Date

	var timestampString: String {
		let dateFormatter = DateFormatter()
		let timeZone = TimeZone(identifier: "UTC")
		dateFormatter.dateFormat = "YYYY-MM-dd'T'HHmm"
		dateFormatter.timeZone = timeZone

		return dateFormatter.string(from: timestamp)
	}

	init(UserId: String, TuneURL_ID: String, Interest_action: String, timestamp: Date = Date())
	{
		self.UserId = UserId
		self.TuneURL_ID = TuneURL_ID
		self.Interest_action = Interest_action
		self.timestamp = timestamp
	}

}

extension ReportingData: Encodable {

	private enum CodingKeys: String, CodingKey {
		case tuneURL_ID = "TuneURL_ID"
		case interest_action = "Interest_action"
		case userId = "UserID"
		case responseTime = "Date"
	}

	func encode(to encoder: Encoder) throws
	{
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(TuneURL_ID, forKey: CodingKeys.tuneURL_ID)
		try container.encode(Interest_action, forKey: CodingKeys.interest_action)

		try container.encode(timestampString, forKey: CodingKeys.responseTime)
		try container.encode(UserId, forKey: CodingKeys.userId)
	}

}
