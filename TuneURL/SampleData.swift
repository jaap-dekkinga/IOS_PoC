//
//  SampleData.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 3/19/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import Foundation


class SampleDataError: NSObject, Codable {

	let desc: String
	let code: Int

	init(desc: String, code: Int)
	{
		self.desc = desc
		self.code = code
		super.init()
	}

	convenience init(error: Error)
	{
		let nsError = error as NSError
		self.init(desc: "Sample Data Error", code: nsError.code)
	}

}

// MARK: -

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
	var pollDataResponse: PollDataResponse?

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
		coder.encode(pollDataResponse, forKey: "pollDataResponse")
	}

	required convenience init?(coder aDecoder: NSCoder)
	{
		let pollDataResponse = aDecoder.decodeObject(forKey: "pollDataResponse") as? PollDataResponse
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
		self.pollDataResponse = pollDataResponse
	}

	// MARK: -

	func prettyDescription() -> String
	{
//		let pollResults = pollDataResponse?.value.first(where: { $0.name == title })
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
//			+ "Poll Data Response: " + (pollResults?.prettyDescription() ?? "missing") + "\n"
			+ "Poll Data Response: " + (pollDataResponse?.prettyDescription(by: title) ?? "missing") + "\n"
			+ "\n"
	}

}

// MARK: -

extension PollDataResponse {

	func prettyDescription(by name: String) -> String
	{
		let allbyName = self.value.filter { (item) -> Bool in
			return item.name == name
		}
		let sumYesNo = allbyName.reduce((yes: 0, no: 0)) { (result, item) in
			return (yes: result.yes + item.numberOfYes, no: result.no + item.numberOfNo)
		}

		return "\n"
			+ "name: " + name + "\n"
			+ "yes count: " + String(sumYesNo.yes) + "\n"
			+ "no count: " + String(sumYesNo.no) + "\n"
			+ "\n"
	}

}

// MARK: -

extension PollDataResponse.PollItem {

	func prettyDescription() -> String {
		return "\n"
			+ "name: " + name + "\n"
			+ "yes count: " + String(numberOfYes) + "\n"
			+ "no count: " + String(numberOfNo) + "\n"
			+ "\n"
	}

}

// MARK: -

class SampleDataManager: NSObject {

	private let userDefaults = UserDefaults.standard
	private(set) var sampleResults: [SampleResult] {
		get {
			guard let archData = userDefaults.object(forKey: #function) as? Data else {
				return []
			}
			let decoder = JSONDecoder()
			let result = (try? decoder.decode([SampleResult].self, from: archData)) ?? []
			return result
		}
		set {
			let encoder = JSONEncoder()
			if let archData = try? encoder.encode(newValue) {
				userDefaults.set(archData, forKey: #function)
			}
		}
	}

	func add(_ sampleResult: SampleResult)
	{
		sampleResults.append(sampleResult)
	}

	func remove(_ sampleResult: SampleResult)
	{
		let ix = sampleResults.firstIndex { (result) -> Bool in
			return sampleResult == result
		}
		guard let ixValue = ix else {
			return
		}

		sampleResults.remove(at: ixValue)
	}

	func remove(ix: Int)
	{
		sampleResults.remove(at: ix)
	}

}
