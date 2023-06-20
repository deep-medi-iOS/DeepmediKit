//
//  Header.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import Alamofire

public class Header: NSObject {
    public enum method: String {
        case post = "POST", get = "GET", put = "PUT", delete = "DELETE"
    }

    public func v2Header(
        method: method,
        uri: String,
        secretKey: String,
        apiKey: String
    ) -> HTTPHeaders {
        let accessKey = "PbDvaXxkTaHf19QGViU1"
        let timeStamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let signature = self.makeV2Signature(method: method.rawValue, uri: uri, timestamp: timeStamp, secretKey: secretKey, accesskey: accessKey)
        let headers: HTTPHeaders = ["x-ncp-apigw-timestamp" : timeStamp,
                                    "x-ncp-apigw-api-key" : apiKey,
                                    "x-ncp-iam-access-key" : accessKey,
                                    "x-ncp-apigw-signature-v2" : signature]
        return headers
    }

    private func makeV2Signature(
        method: String,
        uri: String,
        timestamp: String,
        secretKey: String,
        accesskey: String
    ) -> String {
        let space = " "
        let newLine = "\n"
        let message = "".appending(method)
            .appending(space)
            .appending(uri)
            .appending(newLine)
            .appending(timestamp)
            .appending(newLine)
            .appending(accesskey)
        guard let signature = ObjcMapper.hmacSHA256(secretKey, message: message) else { fatalError("signature error") }
        return signature
    }
}
