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

    func send(sample: Data, name: String) {
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            multipartFormData.append(sample,
                                     withName: name,
                                     fileName: name + ".m4a",
                                     mimeType: "audio/x-m4a")
        }, to: host) { (result) in
            print(result)
        }
    }
}
