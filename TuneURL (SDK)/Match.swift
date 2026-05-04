//
//  Match.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 8/1/21.
//  Copyright © 2021-2022 TuneURL Inc. All rights reserved.
//

import Foundation

public class Match: Codable {

	public let description: String
	public let id: Int
	public let info: String
	public let matchPercentage: Int
	public let name: String
	public let time: Float
	public let type: String

	/// Fingerprint version that produced this match ("V2" or "V1"). Set by the SDK after a successful match.
	/// Not part of the server payload; not encoded.
	public var fingerprintVersion: String?
    
    // MARK: - Init
    init(match: Match, time: Float) {
        self.description = match.description
        self.id = match.id
        self.info = match.info
        self.matchPercentage = match.matchPercentage
        self.name = match.name
        self.type = match.type
		self.fingerprintVersion = match.fingerprintVersion 
        
        self.time = time
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case description = "description"
        case id = "id"
        case info = "info"
        case matchPercentage = "matchPercentage"
        case name = "name"
        case time = "time"
        case type = "type"
    }

	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		description = (try? container.decode(String.self, forKey: .description)) ?? ""
		id = (try? container.decode(Int.self, forKey: .id)) ?? -1
		info = (try? container.decode(String.self, forKey: .info)) ?? ""
		matchPercentage = (try? container.decode(Int.self, forKey: .matchPercentage)) ?? -1
		name = (try? container.decode(String.self, forKey: .name)) ?? ""
		time = (try? container.decode(Float.self, forKey: .time)) ?? 0.0
		type = (try? container.decode(String.self, forKey: .type))?.lowercased() ?? ""
	}

    // MARK: - Description
	public func prettyDescription() -> String {
		return
			"id: \(id)\n" +
			"time: \(time)\n" +
			"name: \(name)\n" +
			"description: \(description)\n" +
			"type: \(type)\n" +
			"info: \(info)\n" +
			"matchPercentage: \(matchPercentage)\n"
			"fingerprintVersion: \(fingerprintVersion ?? "unknown")\n"
	}
}
