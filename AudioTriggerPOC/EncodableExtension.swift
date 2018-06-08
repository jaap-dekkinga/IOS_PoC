//
//  EncodableExtension.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-06-09.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import Alamofire

extension Encodable {
    var parameters: Parameters? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }
        guard let dict = (try? JSONSerialization
            .jsonObject(with: data, options: .allowFragments))
            .flatMap({ $0 as? Parameters }),
            dict.keys.count > 0 else {

                return nil
        }

        return dict
    }
}
