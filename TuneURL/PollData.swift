//
//  PollData.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 6/8/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import Foundation


struct PollResponse: Codable {

	struct PollItem: Codable {
		let numberOfYes: Int
		let numberOfNo: Int
		let timeStamp: String
		let name: String
	}

	let value: [PollItem]
	let statusCode: Int

}

// MARK: -

class PollData {

	let name: String
	let response: Bool
	let timestamp: Date

	var responseString: String {
		return response ? "yes" : "no"
	}

	var timestampString: String {
		let dateFormatter = DateFormatter()
		let timeZone = TimeZone(identifier: "UTC")
		dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
		dateFormatter.timeZone = timeZone

		return dateFormatter.string(from: timestamp)
	}

	init(response: Bool, name: String, timestamp: Date = Date())
	{
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

	func encode(to encoder: Encoder) throws
	{
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(responseString, forKey: CodingKeys.response)
		try container.encode(name, forKey: CodingKeys.name)
		try container.encode(timestampString, forKey: CodingKeys.responseTime)
	}

}
