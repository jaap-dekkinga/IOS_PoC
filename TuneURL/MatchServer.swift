//
//  MatchServer.swift
//  TuneURL
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/23/19.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import Alamofire
import Foundation


class MatchServerError {

	let description: String
	let code: Int

	// MARK: -

	init(description: String, code: Int)
	{
		self.description = description
		self.code = code
	}

	convenience init(error: NSError)
	{
		self.init(description: error.localizedDescription, code: error.code)
	}

}

// MARK: -

class MatchServer: NSObject {

	enum MatchServerResult {
		case success(SampleData)
		case failure(MatchServerError)
	}

	// static
	static let shared = MatchServer()

	// match server configuration
	private let serverHost = "ec2-54-213-252-225.us-west-2.compute.amazonaws.com"
	private let serverPath = "/api/match"

	// MARK: -

	func requestMatch(for fileURL: URL, completion: ((SampleData?) -> Void)? = nil)
	{
#if DEBUG
		print("Requesting match for: \(fileURL)")
#endif // DEBUG

		// send the recording to the match server
		sendRecording(fileURL: fileURL, completion: {
			(response) in

			switch response {
				case .success(let matchResponse):
					completion?(matchResponse)
				case .failure:
					completion?(nil)
			}
		})
	}

	// MARK: -
	// MARK: Private

	func sendRecording(fileURL: URL, name: String? = nil, completion: ((MatchServerResult) -> Void)?)
	{
		// get the server url
		guard let serverURL = URL(string: ("http://" + serverHost + serverPath)) else {
			return
		}

		// upload the recording
		Alamofire.upload(multipartFormData: {
			(multipartFormData) in

			// prepare the form dat
			multipartFormData.append(fileURL, withName: "file")

		}, to: serverURL) {
			(result) in

			// parse the server response
			switch result {
				case .success(let upload, _, _):
					upload.responseJSON {
						(response) in

						// check for an error
						if let error = response.error {
							print("MatchServer: Response error: \(error.localizedDescription)")
							let nsError = error as NSError
							completion?(.failure(MatchServerError(error: nsError)))
							return
						}

						// parse the response json
						guard let jsonRoot = response.result.value as? [String : Any],
								let mainDict = jsonRoot["data"] as? [String : Any],
								let matchResponse = SampleData(jsonDict: mainDict) else {
							// return a parsing error
							let error = NSError(domain: "App", code: -1, userInfo: nil)
							completion?(.failure(MatchServerError(error: error)))
							return
						}

#if DEBUG
						print("Server response: \(jsonRoot)")
#endif // DEBUG

						// return the match result
						completion?(.success(matchResponse))
					}

				case .failure(let error):
					print("MatchServer: Upload error: \(error.localizedDescription)")
					let nsError = error as NSError
					completion?(.failure(MatchServerError(error: nsError)))
			}
		}
	}

}
