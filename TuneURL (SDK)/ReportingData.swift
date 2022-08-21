//
//  ReportingData.swift
//  TuneURL (SDK)
//
//  Created by Jaap Dekkinga.
//  Copyright © 2020-2022 TuneURL Inc. All rights reserved.
//


import Foundation


class ReportingData {

	let action: Reporting.Action
	let time: Date
	let tuneURLID: Int
	let userID: String?

	var timeString: String {
		let dateFormatter = DateFormatter()
		let timeZone = TimeZone(identifier: "UTC")
		dateFormatter.dateFormat = "YYYY-MM-dd'T'HHmm"
		dateFormatter.timeZone = timeZone
		return dateFormatter.string(from: time)
	}

	init(action: Reporting.Action, tuneURLID: Int, userID: String?, time: Date = Date())
	{
		self.action = action
		self.time = time
		self.tuneURLID = tuneURLID
		self.userID = userID
	}

}

extension ReportingData: Encodable {

	private enum CodingKeys: String, CodingKey {
		case action = "Interest_action"
		case time = "Date"
		case tuneURLID = "TuneURL_ID"
		case userID = "UserID"
	}

	func encode(to encoder: Encoder) throws
	{
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(action.rawValue, forKey: CodingKeys.action)
		try container.encode(timeString, forKey: CodingKeys.time)
		try container.encode("\(tuneURLID)", forKey: CodingKeys.tuneURLID)
		try container.encode(userID, forKey: CodingKeys.userID)
	}

}

// MARK: -

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
