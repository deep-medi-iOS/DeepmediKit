//
//  Header.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit

public final class Header {
    public init() {}
    public enum HeaderErr: Error {
        case messegae(String)
    }
    
    public func getHeader(
        uri: String,
        apiKey: String
    ) async throws -> [String: String] {
        let urlString = "https://y8gc8ito4a.apigw.ntruss.com/signature/v1/"
        guard let url = URL(string: urlString) else {
            throw Header.HeaderErr.messegae("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "uri": uri,
            "method": "POST",
            "api_key": apiKey
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Header.HeaderErr.messegae("Invalid response")
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Header.HeaderErr.messegae("status code error: \(httpResponse.statusCode)")
        }
        
        let decoded = try JSONDecoder().decode(DeepmediHeader.self, from: data)
        
        return [
            "x-ncp-apigw-api-key"      : apiKey,
            "x-ncp-apigw-timestamp"    : decoded.timestamp,
            "x-ncp-iam-access-key"     : decoded.accessKey,
            "x-ncp-apigw-signature-v1" : decoded.signature
        ]
    }
}

public struct DeepmediHeader: Codable {
    public let signature: String
    public let timestamp: String
    public let accessKey: String
}
