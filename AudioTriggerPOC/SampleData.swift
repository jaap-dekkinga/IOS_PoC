//
//  SampleData.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-19.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Foundation

class SampleData: NSObject, NSCoding {
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
    }

    public required convenience init?(coder aDecoder: NSCoder) {
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
    }
}

extension SampleData {
    func prettyDescription() -> String {
        return "\n"
            + "status: " + status + "\n"
            + "confidence: " + String(confidence) + "\n"
            + "description: " + desc + "\n"
            + "sha1: " + sha1 + "\n"
            + "match time: " + matchTime + "\n"
            + "offset: " + offset + "\n"
            + "offset (secs): " + offsetSeconds + "\n"
            + "song id: " + songId + "\n"
            + "song name: " + songName + "\n"
            + "title: " + title + "\n"
            + "url: " + url + "\n"
            + "\n"
    }
}

protocol SampleDataManagerDelegate {
    func didChange()
}

class SampleDataManager: NSObject {
    static var delegate: SampleDataManagerDelegate?
    private let userDefaults = UserDefaults.standard
    private(set) var samples: [SampleData] {
        get {
            guard let archData = userDefaults.object(forKey: #function) as? Data else {
                return []
            }
            return NSKeyedUnarchiver.unarchiveObject(with: archData) as? [SampleData] ?? []
//            return userDefaults.array(forKey: "samples") as? [SampleData] ?? []
        }
        set {
            let archData = NSKeyedArchiver.archivedData(withRootObject: newValue)
            userDefaults.set(archData, forKey: #function)
            SampleDataManager.delegate?.didChange()
        }
    }

    func add(_ sample: SampleData) {
        samples.append(sample)
    }

    func remove(_ sample: SampleData) {
        guard let ix = samples.index(of: sample) else {
            return
        }

        samples.remove(at: ix)
    }

    func remove(ix: Int) {
        samples.remove(at: ix)
    }
}

