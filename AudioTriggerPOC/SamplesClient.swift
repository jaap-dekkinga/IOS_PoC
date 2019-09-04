//
//  SaveClient.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-18.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Alamofire

enum SampleResult {
    case success(SampleData)
    case failure(SampleDataError)
}

extension SampleResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case success
        case failure
    }

    enum SampleResultCodingError: Error {
        case decoding(String)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? values.decode(SampleData.self, forKey: CodingKeys.success) {
            self = .success(value)
            return
        }
        if let value = try? values.decode(SampleDataError.self, forKey: CodingKeys.failure) {
            self = .failure(value)
            return
        }
        throw SampleResultCodingError.decoding("Whoops! \(dump(values))")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let sampleData):
            try container.encode(sampleData, forKey: CodingKeys.success)
        case .failure(let error):
            try container.encode(error, forKey: CodingKeys.failure)
        }
    }
}

extension SampleResult: Equatable {
    public static func == (lhs: SampleResult, rhs: SampleResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let lhsValue), .success(let rhsValue)):
            return lhsValue == rhsValue
        case (.failure(let lhsError), .failure(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

typealias completionHandler = (SampleResult) -> Void

class SamplesClient: NSObject {

    // "ec2-34-208-97-117.us-west-2.compute.amazonaws.com"
    // "2600:1f14:2b5:e614:115e:850e:e4ce:eba7"
    // "35.163.163.91"
//    private let host = "35.163.163.91"
	private let host = "ec2-54-213-252-225.us-west-2.compute.amazonaws.com"
    private let path = "/api/match"
    private var url: String {
        return "http://" + host + path
    }

    func send(sampleUrl: URL, name: String? = nil, completion: completionHandler?) {
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            multipartFormData.append(sampleUrl, withName: "file")
        }, to: url) { (result) in

            switch result {
            case .success(let upload, _, _):
                upload.responseJSON { response in

                    if let error = response.error {
                        print("Error in response: \(error.localizedDescription)")
                        completion?(.failure(SampleDataError(error: error)))
                        return
                    }

                    guard let jsonRoot = response.result.value as? [String: Any],
                        let mainDict = jsonRoot["data"] as? [String: Any],
                        let sampleData = SampleData(jsonDict: mainDict) else {
                            let error = NSError(domain: "App", code: -1, userInfo: nil)

                            completion?(.failure(SampleDataError(error: error)))
                            return
                    }

					print("Server response: \(jsonRoot)")

					completion?(.success(sampleData))
                }
            case .failure(let error):
                print("Error in upload: \(error.localizedDescription)")
                completion?(.failure(SampleDataError(error: error)))
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
