//
//  SaveClient.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-18.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Alamofire

typealias completionHandler = (SampleData?) -> Void

class SamplesClient: NSObject {

    private let host = "35.163.163.91"
    private let path = "/api/match"
    private var url: String {
        return "http://" + host + path
    }

    func send(sampleUrl: URL, name: String, completion: completionHandler?) {
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            multipartFormData.append(sampleUrl, withName: "file")
        }, to: url) { (result) in

            switch result {
            case .success(let upload, _, _):
                upload.responseJSON { response in

                    // Put the result in sampleData
                    var sampleData: SampleData? = nil
                    defer {
                        completion?(sampleData)
                    }

                    if let error = response.error {
                        print("Error in response: \(error.localizedDescription)")
                        return
                    }

                    guard let jsonRoot = response.result.value as? [String: Any],
                        let mainDict = jsonRoot["data"] as? [String: Any] else {
                            return
                    }

                    sampleData = SampleData(jsonDict: mainDict)
                }
            case .failure(let error):
                print("Error in upload: \(error.localizedDescription)")
                completion?(nil)
            }
        }
    }
}

extension SampleData {
    convenience init?(jsonDict: [String: Any]) {
        let status = jsonDict["status"] as? String ?? "n/a"
        let confidence = jsonDict["confidence"] as? Int ?? 0
        let sha1 = jsonDict["file_sha1"] as? String ?? "n/a"
        let matchTime = jsonDict["match_time"] as? Double ?? 0
        let offset = jsonDict["offset"] as? Int ?? 0
        let offsetSeconds = jsonDict["offset_seconds"] as? Double  ?? 0
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
}
