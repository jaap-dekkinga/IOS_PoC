//
//  SampleData.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-19.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation

class SampleDataError: NSObject, Codable {
    let desc: String
    let code: Int

    init(desc: String, code: Int) {
        self.desc = desc
        self.code = code
        super.init()
    }

    convenience init(error: Error) {
        let nsError = error as NSError
        self.init(desc: "Sample Data Error", code: nsError.code)
    }
}

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

    init(status: String, confidence: Int, desc: String, sha1: String,
         matchTime: String, offset: String, offsetSeconds: String,
         songId: String, songName: String, title: String, url: String) {

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

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(status, forKey: "status")
        aCoder.encode(confidence, forKey: "confidence")
        aCoder.encode(desc, forKey: "description")
        aCoder.encode(sha1, forKey: "file_sha1")
        aCoder.encode(matchTime, forKey: "match_time")
        aCoder.encode(offset, forKey: "offset")
        aCoder.encode(offsetSeconds, forKey: "offset_seconds")
        aCoder.encode(songId, forKey: "song_id")
        aCoder.encode(songName, forKey: "song_name")
        aCoder.encode(title, forKey: "title")
        aCoder.encode(url, forKey: "url")
        aCoder.encode(pollDataResponse, forKey: "pollDataResponse")
    }

    public required convenience init?(coder aDecoder: NSCoder) {
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
        self.pollDataResponse = pollDataResponse
    }
}

extension SampleData {
    func prettyDescription() -> String {
        let pollResults = pollDataResponse?.value.first(where: { $0.name == title })
        return "\n"
            + "status: " + status + "\n"
//            + "confidence: " + String(confidence) + "\n"
//            + "description: " + desc + "\n"
//            + "sha1: " + sha1 + "\n"
//            + "match time: " + matchTime + "\n"
//            + "offset: " + offset + "\n"
//            + "offset (secs): " + offsetSeconds + "\n"
            + "song id: " + songId + "\n"
            + "song name: " + songName + "\n"
            + "title: " + title + "\n"
//            + "url: " + url + "\n"
            + "\n"
            + "Poll Data Response: " + (pollResults?.prettyDescription() ?? "missing") + "\n"
            + "\n"
    }
}

extension PollDataResponse.PollItem {
    func prettyDescription() -> String {
        return "\n"
            + "name: " + name + "\n"
            + "yes count: " + String(numberOfYes) + "\n"
            + "no count: " + String(numberOfNo) + "\n"
            + "\n"
    }
}

protocol SampleDataManagerDelegate {
    func didChange()
}

class SampleDataManager: NSObject {
    static var delegate: SampleDataManagerDelegate?
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
                SampleDataManager.delegate?.didChange()
            }
        }
    }

    func add(_ sampleResult: SampleResult) {
        sampleResults.append(sampleResult)
    }

    func remove(_ sampleResult: SampleResult) {
        let ix = sampleResults.index { (result) -> Bool in
            return sampleResult == result
        }
        guard let ixValue = ix else {
            return
        }


        sampleResults.remove(at: ixValue)
    }

    func remove(ix: Int) {
        sampleResults.remove(at: ix)
    }
}

