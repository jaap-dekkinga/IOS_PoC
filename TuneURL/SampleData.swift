//
//  SampleData.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 3/19/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import Foundation


class SampleData: NSObject, NSCoding, Codable {

	let status: String
	let confidence: Int
	let desc: String
	let sha1: String
	let matchTime: String
	let offset: String
	let offsetSeconds: String
	let songId: String
	let songName: String
	let title: String
	let url: String

	// MARK: -

	init(status: String, confidence: Int, desc: String, sha1: String, matchTime: String, offset: String, offsetSeconds: String, songId: String, songName: String, title: String, url: String)
	{
		self.status = status
		self.confidence = confidence
		self.desc = desc
		self.sha1 = sha1
		self.matchTime = matchTime
		self.offset = offset
		self.offsetSeconds = offsetSeconds
		self.songId = songId
		self.songName = songName
		self.title = title
		self.url = url
	}

	convenience init?(jsonDict: [String: Any])
	{
		let status = jsonDict["status"] as? String ?? "n/a"
		let confidence = jsonDict["confidence"] as? Int ?? 0
		let sha1 = jsonDict["file_sha1"] as? String ?? "n/a"
		let matchTime = jsonDict["match_time"] as? Double ?? 0.0
		let offset = jsonDict["offset"] as? Int ?? 0
		let offsetSeconds = jsonDict["offset_seconds"] as? Double ?? 0.0
		let songId = jsonDict["song_id"] as? Int ?? 0
		let songName = jsonDict["song_name"] as? String ?? "n/a"
		let desc = jsonDict["description"] as? String ?? "n/a"
		let title = jsonDict["title"] as? String ?? "n/a"
		let url = jsonDict["url"] as? String ?? "n/a"

		self.init(status: status,
				confidence: confidence,
				desc: desc,
				sha1: sha1,
				matchTime: String(matchTime),
				offset: String(offset),
				offsetSeconds: String(offsetSeconds),
				songId: String(songId),
				songName: songName,
				title: title,
				url: url)
	}

	func encode(with coder: NSCoder)
	{
		coder.encode(status, forKey: "status")
		coder.encode(confidence, forKey: "confidence")
		coder.encode(desc, forKey: "description")
		coder.encode(sha1, forKey: "file_sha1")
		coder.encode(matchTime, forKey: "match_time")
		coder.encode(offset, forKey: "offset")
		coder.encode(offsetSeconds, forKey: "offset_seconds")
		coder.encode(songId, forKey: "song_id")
		coder.encode(songName, forKey: "song_name")
		coder.encode(title, forKey: "title")
		coder.encode(url, forKey: "url")
	}

	required convenience init?(coder aDecoder: NSCoder)
	{
		let confidence = aDecoder.decodeInteger(forKey: "confidence")
		guard let status = aDecoder.decodeObject(forKey: "status") as? String,
			let desc = aDecoder.decodeObject(forKey: "description") as? String,
			let sha1 = aDecoder.decodeObject(forKey: "file_sha1") as? String,
			let matchTime = aDecoder.decodeObject(forKey: "match_time") as? String,
			let offset = aDecoder.decodeObject(forKey: "offset") as? String,
			let offsetSeconds = aDecoder.decodeObject(forKey: "offset_seconds") as? String,
			let songId = aDecoder.decodeObject(forKey: "song_id") as? String,
			let songName = aDecoder.decodeObject(forKey: "song_name") as? String,
			let title = aDecoder.decodeObject(forKey: "title") as? String,
			let url = aDecoder.decodeObject(forKey: "url") as? String else {
				return nil
		}

		self.init(status: status, confidence: confidence, desc: desc, sha1: sha1, matchTime: String(matchTime), offset: String(offset), offsetSeconds: String(offsetSeconds), songId: String(songId), songName: songName, title: title, url: url)
	}

	// MARK: -

	func prettyDescription() -> String
	{
		return "\n"
			+ "status: " + status + "\n"
//			+ "confidence: " + String(confidence) + "\n"
//			+ "description: " + desc + "\n"
//			+ "sha1: " + sha1 + "\n"
//			+ "match time: " + matchTime + "\n"
//			+ "offset: " + offset + "\n"
//			+ "offset (secs): " + offsetSeconds + "\n"
			+ "song id: " + songId + "\n"
			+ "song name: " + songName + "\n"
			+ "title: " + title + "\n"
//			+ "url: " + url + "\n"
			+ "\n"
			+ "\n"
	}

}
