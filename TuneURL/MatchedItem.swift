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
		case coupon = 4
	}

	// public
	var favorite = false

	// public (read-only)
	public private(set) var action: Action = .none
    public private(set) var songId: Int?
	public private(set) var matchedTime = Date()
	public private(set) var phoneNumber: String?
	public private(set) var pollID: String?
	public private(set) var title: String = ""
	public private(set) var url: URL?
	public private(set) var uuid = UUID().uuidString

	// MARK: -

	var notificationTitle: String? {
		switch action {
			case .coupon:
				return "You've received a coupon!"
			case .phoneNumber:
				if let phoneNumberString = phoneNumber {
					return ("Save phone number " + phoneNumberString + "?")
				} else {
					return "Save phone number?"
				}
			case .poll:
				return "Vote in the TuneURL Poll!"
			case .webPage:
				return "Save Web Page?"
			default:
				return nil
		}
	}

	var phoneURL: URL? {
		if let phoneNumber = self.phoneNumber {
			return URL(string: ("tel:" + phoneNumber))
		}
		return nil
	}

	// private
	private enum Keys: String, CodingKey {
		case action = "Action"
		case favorite = "Favorite"
        case songId = "Song Id"
		case matchedTime = "Matched Time"
		case phoneNumber = "Phone Number"
		case pollID = "Poll ID"
		case title = "Title"
		case url = "URL"
		case uuid = "UUID"
	}

	// MARK: -

	convenience init(with sampleData: SampleData)
	{
		self.init()

		// parse the sample data description
		switch (sampleData.desc.lowercased()) {
			case "coupon":
				action = .coupon
			case "phone":
				action = .phoneNumber
			case "poll":
				action = .poll
			case "open_page", "save_page":
				action = .webPage
			default:
				action = .none
		}
        
        uuid = UUID().uuidString
        title = sampleData.songName
        songId = sampleData.songId
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

		matchedTime = Date.distantPast

		let container = try decoder.container(keyedBy: MatchedItem.Keys.self)

		if let decodedAction: Action = try? container.decode(Action.self, forKey: .action) {
			action = decodedAction
		}
		if let decodedFavorite: Bool = try? container.decode(Bool.self, forKey: .favorite) {
			favorite = decodedFavorite
		}
		if let decodedMatchedTime: Date = try? container.decode(Date.self, forKey: .matchedTime) {
			matchedTime = decodedMatchedTime
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
        if let decodedUUID: String = try? container.decode(String.self, forKey: .uuid) {
            uuid = decodedUUID
        }
        if let decodedsongId: Int = try? container.decode(Int.self, forKey: .songId) {
            songId = decodedsongId
        }
	}

	func encode(to encoder: Encoder) throws
	{
		var container = encoder.container(keyedBy: MatchedItem.Keys.self)
		try container.encode(action, forKey: .action)
		try container.encode(favorite, forKey: .favorite)
		try container.encode(matchedTime, forKey: .matchedTime)
        try container.encode(title, forKey: .title)
        try container.encode(songId, forKey: .songId)
		if let phoneNumber = self.phoneNumber {
			try container.encode(phoneNumber, forKey: .phoneNumber)
		}
		if let pollID = self.pollID {
			try container.encode(pollID, forKey: .pollID)
		}
		if let url = self.url {
			try container.encode(url, forKey: .url)
		}
		try container.encode(uuid, forKey: .uuid)
	}

}
