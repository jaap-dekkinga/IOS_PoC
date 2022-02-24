//
//  EncodableExtension.swift
//  TuneURL
//
//  Created by Aleksandar Mihailovski on 6/9/18.
//  Copyright © 2018-2022 TuneURL Inc. All rights reserved.
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
