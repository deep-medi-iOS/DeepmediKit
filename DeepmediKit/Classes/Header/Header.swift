//
//  Header.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import Alamofire

public final class Header {
    public init() {}
    public enum HeaderErr: Error {
        case messegae(String)
    }
    
    public func getHeader(
        uri: String,
        apiKey: String
    ) async throws -> HTTPHeaders {
        let headerURL = "https://y8gc8ito4a.apigw.ntruss.com/signature/v1/"
        let headerParams = [
            "uri": uri,
            "method": "POST",
            "api_key": apiKey
        ]
        
        let resp = await AF.request(
            headerURL,
            method: .post,
            parameters: headerParams
        )
            .serializingDecodable(DeepmediHeader.self).response
        
        if let afErr = resp.error {
            throw Header.HeaderErr.messegae("response error: \(afErr.localizedDescription)")
        }
        
        if let statusCode = resp.response?.statusCode,
           !(200..<300).contains(statusCode) {
            throw Header.HeaderErr.messegae("status code error: \(statusCode)")
        } else if let value = resp.value {
            return [
                "x-ncp-apigw-api-key"      : apiKey,
                "x-ncp-apigw-timestamp"    : value.timestamp,
                "x-ncp-iam-access-key"     : value.accessKey,
                "x-ncp-apigw-signature-v1" : value.signature
            ]
        }
        return [
            "x-ncp-apigw-api-key"      : "",
            "x-ncp-apigw-timestamp"    : "",
            "x-ncp-iam-access-key"     : "",
            "x-ncp-apigw-signature-v1" : ""
        ]
    }
}

public struct DeepmediHeader: Codable {
    public let signature: String
    public let timestamp: String
    public let accessKey: String
}

