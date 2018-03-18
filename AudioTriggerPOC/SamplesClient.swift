//
//  SaveClient.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-18.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Alamofire

class SamplesClient: NSObject {

    private let host = "35.163.163.91"
    private let path = "/api/match"
    private var url: String {
        return "http://" + host + path
    }

    func send(sampleUrl: URL, name: String) {
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            multipartFormData.append(sampleUrl, withName: "file",
                                     fileName: "up.mp3",
                                     mimeType: "audio/mp3")
        }, to: url) { (result) in
            switch result {
            case .success(let upload, _, _):
                upload.responseJSON { response in
                    if let error = response.error {
                        print("Error in response: \(error.localizedDescription)")
                        return
                    }
                    print(response)
                }
            case .failure(let error):
                print("Error in upload: \(error.localizedDescription)")
            }
        }
    }
}
