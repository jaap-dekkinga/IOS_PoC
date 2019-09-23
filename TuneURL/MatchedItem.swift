//
//  MatchedItem.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/22/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


class MatchedItem: Codable {

	// item actions
	enum Action: Int, Codable {
		case none = 0
		case phoneNumber = 1
		case poll = 2
		case webPage = 3
	}

	// public (read-only)
	public private(set) var action: Action = .none
	public private(set) var phoneNumber: String?
	public private(set) var pollID: String?
	public private(set) var title: String = ""
	public private(set) var url: URL?

	var phoneURL: URL? {
		if let phoneNumber = self.phoneNumber {
			return URL(string: ("tel:" + phoneNumber))
		}
		return nil
	}

	// private
	private enum Keys: String, CodingKey {
		case action = "Action"
		case phoneNumber = "Phone Number"
		case pollID = "Poll ID"
		case title = "Title"
		case url = "URL"
	}

	// MARK: -

	convenience init(with sampleData: SampleData)
	{
		self.init()

		// parse the sample data description
		switch (sampleData.desc.lowercased()) {
			case "phone":
				action = .phoneNumber
			case "poll":
				action = .poll
			case "open_page", "save_page":
				action = .webPage
			default:
				action = .none
		}

		title = sampleData.songName
		if (action == .phoneNumber) {
			phoneNumber = sampleData.title
		}
		if (action == .poll) {
			pollID = sampleData.title
		}
		if (sampleData.url != "") {
			url = URL(string: sampleData.url)
		}
	}

	// MARK: -
	// MARK: Codable

	required convenience init(from decoder: Decoder) throws
	{
		self.init()

		let container = try decoder.container(keyedBy: MatchedItem.Keys.self)

		if let decodedAction: Action = try? container.decode(Action.self, forKey: .action) {
			action = decodedAction
		}
		if let decodedTitle: String = try? container.decode(String.self, forKey: .title) {
			title = decodedTitle
		}
		if let decodedPhoneNumber: String = try? container.decode(String.self, forKey: .phoneNumber) {
			phoneNumber = decodedPhoneNumber
		}
		if let decodedPollID: String = try? container.decode(String.self, forKey: .pollID) {
			pollID = decodedPollID
		}
		if let decodedURL: URL = try? container.decode(URL.self, forKey: .url) {
			url = decodedURL
		}
	}

	func encode(to encoder: Encoder) throws
	{
		var container = encoder.container(keyedBy: MatchedItem.Keys.self)
		try container.encode(action, forKey: .action)
		try container.encode(title, forKey: .title)
		if let phoneNumber = self.phoneNumber {
			try container.encode(phoneNumber, forKey: .phoneNumber)
		}
		if let pollID = self.pollID {
			try container.encode(pollID, forKey: .pollID)
		}
		if let url = self.url {
			try container.encode(url, forKey: .url)
		}
	}

}
