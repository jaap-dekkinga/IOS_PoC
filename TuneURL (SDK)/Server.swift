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
                    // SDK-DIAG: log the body on non-2xx too — many APIs put
                    // useful error detail in the body even on 4xx/5xx
                    let bodyString = String(data: data, encoding: .utf8) ?? "(non-utf8 body, \(data.count) bytes)"
                    NSLog("[SDK-DIAG] Server returned status \(response.statusCode). Body: \(bodyString)")
                    completion?(nil)
                    return
                }
                
                // SDK-DIAG: log the raw body every time, so we can see the
                // actual shape of a successful response while debugging
                let bodyString = String(data: data, encoding: .utf8) ?? "(non-utf8 body, \(data.count) bytes)"
                NSLog("[SDK-DIAG] Server response body: \(bodyString)")
                
                // decode the response — use do/catch instead of try? so we
                // can see WHY decoding failed (missing key, type mismatch,
                // wrapped-object-vs-bare-array, etc.) instead of just "it failed"
                let decoder = JSONDecoder()
                do {
                    let object = try decoder.decode(T.self, from: data)
                    completion?(object)
                } catch {
                    NSLog("[SDK-DIAG] Error decoding server response as \(T.self): \(error)")
                    completion?(nil)
                }
            }
        }
        
        // start the request
        task.resume()
    }
}
