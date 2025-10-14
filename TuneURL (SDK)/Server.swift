//
//  Server.swift
//  TuneURL (SDK)
//
//  Created by Gerrit Goossen <developer@gerrit.email> on 9/23/19.
//  Copyright © 2019-2022 TuneURL Inc. All rights reserved.
//

import Foundation
@_implementationOnly import Fingerprint_Private

class Server {
    
    // MARK: - Static props
    static let shared = Server()
    
    // MARK: - Private props
    // match server configuration
    private let serverHost = "pnz3vadc52.execute-api.us-east-2.amazonaws.com"
    private let serverMatchPath = "/dev/search-fingerprint"
    
    // MARK: - Public funcs
    func matchFingerprint(
        for fingerprintData: [UInt8],
        queue: DispatchQueue?,
        completion: ((Match?) -> Void)? = nil
    ) {
#if DEBUG
        print("TuneURL: Requesting fingerprint match.")
#endif // DEBUG
        
        // create the request url
        guard let requestURL = URL(string: ("https://" + serverHost + serverMatchPath)) else {
            NSLog("TuneURL: Error creating url for server request.")
            return
        }
        
        // create the request parameters
        let fingerprintParameters: [String : Any] = [
            "type" : "buffer",
            "data" : fingerprintData
        ]
        let parameters = [
            "fingerprint" : fingerprintParameters
        ]
        
        // convert the parameters to json data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted) else {
            NSLog("TuneURL: Error creating json data for server request.")
            completion?(nil)
            return
        }
        
        // create the request
        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60.0
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // make the request
        makeRequest(request, queue: queue, responseType: [Match].self) {
            responseObject in
            
            // get the response
            guard let matchResponses = responseObject else {
                completion?(nil)
                return
            }
            
            // find the best match response
            var match: Match?
            var bestPercentage = -1
            
            for item in matchResponses {
                if (item.matchPercentage > bestPercentage) {
                    bestPercentage = item.matchPercentage
                    match = item
                }
            }
            
            // call the completion handler
            completion?(match)
        }
    }
    
    // MARK: - Private funcs
    private func makeRequest<T: Decodable>(
        _ request: URLRequest,
        queue: DispatchQueue?,
        responseType: T.Type,
        completion: ((T?) -> Void)? = nil
    ) {
        let dispatchQueue = queue ?? DispatchQueue.main
        
        let task = URLSession.shared.dataTask(with: request) {
            (data: Data?, response: URLResponse?, error: Error?) in
            
            dispatchQueue.async {
                // check for errors
                guard (error == nil), let data = data, (data.count > 0),
                      let response = response as? HTTPURLResponse else {
                    NSLog("TuneURL: Server returned error: \(error?.localizedDescription ?? "(unknown error)")")
                    completion?(nil)
                    return
                }
                
                // check the http response status code
                guard ((response.statusCode >= 200) && (response.statusCode <= 299)) else {
                    NSLog("TuneURL: Server returned unhandled status code: \(response.statusCode)")
                    completion?(nil)
                    return
                }
                
                // decode the response
                let decoder = JSONDecoder()
                guard let object = try? decoder.decode(T.self, from: data) else {
                    NSLog("TuneURL: Error decoding server response.")
                    completion?(nil)
                    return
                }
                
                // call the completion handler
                completion?(object)
            }
        }
        
        // start the request
        task.resume()
    }
}
