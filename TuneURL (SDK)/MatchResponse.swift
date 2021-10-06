//
//  MatchResponse.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/1/21.
//  Copyright © 2021 TuneURL Inc. All rights reserved.
//


import Foundation


public class MatchResponse: Codable {

	public let description: String
	public let id: Int
	public let info: String
	public let matchPercentage: Int
	public let name: String
	public let type: String

	// MARK: -

	enum CodingKeys: String, CodingKey {
		case description = "description"
		case id = "id"
		case info = "info"
		case matchPercentage = "matchPercentage"
		case name = "name"
		case type = "type"
	}

	// MARK: -

	public required init(from decoder: Decoder) throws
	{
		let container = try decoder.container(keyedBy: CodingKeys.self)

		description = (try? container.decode(String.self, forKey: .description)) ?? ""
		id = (try? container.decode(Int.self, forKey: .id)) ?? -1
		info = (try? container.decode(String.self, forKey: .info)) ?? ""
		matchPercentage = (try? container.decode(Int.self, forKey: .matchPercentage)) ?? -1
		name = (try? container.decode(String.self, forKey: .name)) ?? ""
		type = (try? container.decode(String.self, forKey: .type))?.lowercased() ?? ""
	}

	// MARK: -

	public func prettyDescription() -> String
	{
		return
			"id: \(id)\n" +
			"name: \(name)\n" +
			"description: \(description)\n" +
			"type: \(type)\n" +
			"info: \(info)\n" +
			"matchPercentage: \(matchPercentage)\n"
	}

}
