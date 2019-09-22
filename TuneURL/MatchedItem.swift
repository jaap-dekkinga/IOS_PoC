//
//  MatchedItem.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/22/19.
//  Copyright © 2019 TuneURL Inc. All rights reserved.
//


import Foundation


enum MatchedItemKeys: String, CodingKey {

	case title = "Title"

}


class MatchedItem: Codable {

	// public (read-only)
	public private(set) var title: String = ""

	// MARK: -

	convenience init(with sampleData: SampleData)
	{
		self.init()

		title = sampleData.title
	}

	// MARK: -
	// MARK: Codable

	required convenience init(from decoder: Decoder) throws
	{
		self.init()

		let container = try decoder.container(keyedBy: MatchedItemKeys.self)

		if let decodedTitle: String = try? container.decode(String.self, forKey: .title) {
			title = decodedTitle
		}
	}

	func encode(to encoder: Encoder) throws
	{
		var container = encoder.container(keyedBy: MatchedItemKeys.self)
		try container.encode(title, forKey: .title)
	}

}
