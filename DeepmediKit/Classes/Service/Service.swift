//
//  Service.swift
//
//  Created by 딥메디 on 2/27/24.
//

import Foundation

public enum GenderType: Int, Codable {
    case male = 0
    case female = 1
}

public enum DeepmediServiceError: Error {
    case invalidURL(String)
    case invalidResponse
    case statusCode(Int, String)
    case apiResult(Int, String)
}

extension DeepmediServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response"
        case .statusCode(let code, let body):
            return "status code error: \(code), body: \(body)"
        case .apiResult(let result, let message):
            return "api result error: \(result), message: \(message)"
        }
    }
}

public struct EstimateStressFromRr: Codable {
    public let physicalStressCalib: Double

    public init(physicalStressCalib: Double) {
        self.physicalStressCalib = physicalStressCalib
    }

    private enum CodingKeys: String, CodingKey {
        case physicalStressCalib = "physicalStress_calib"
    }
}

public struct EstimateSingleBpVital: Codable {
    public let sys: Double
    public let dia: Double

    public init(
        sys: Double,
        dia: Double
    ) {
        self.sys = sys
        self.dia = dia
    }
}

public struct BPFeatureExtraction: Codable {
    public let ft: [Double]

    public var features: [Double] {
        ft
    }

    public init(ft: [Double]) {
        self.ft = ft
    }

    private enum CodingKeys: String, CodingKey {
        case ft
    }
}

public final class EstimateStressFromRrProvider {
    private let network: DeepmediAPIClient

    public init(apiKey: String) {
        self.network = DeepmediAPIClient(apiKey: apiKey)
    }

    public func getEstimateStressFromRr(
        rrList: [Double],
        age: Int,
        gender: GenderType,
        k: Int
    ) async throws -> EstimateStressFromRr {
        let request = EstimateStressFromRrRequest(
            rrList: rrList,
            age: age,
            gender: gender,
            k: k
        )
        return try await network.post(
            urlString: "https://j3z0wvonif.apigw.ntruss.com/calculate_face/v1/estimate_stress_from_rr",
            body: request
        )
    }
}

public final class EstimateSingleBpVitalProvider {
    private let network: DeepmediAPIClient

    public init(apiKey: String) {
        self.network = DeepmediAPIClient(apiKey: apiKey)
    }

    public func getEstimateSingleBpVital(
        cuffSys: Int,
        cuffDia: Int,
        calibFt: [Double],
        targetFt: [Double]
    ) async throws -> EstimateSingleBpVital {
        let request = EstimateSingleBpVitalRequest(
            cuff_sys: cuffSys,
            cuff_dia: cuffDia,
            calib_ft: calibFt,
            target_ft: targetFt
        )
        return try await network.post(
            urlString: "https://i40d9fg0vx.apigw.ntruss.com/bp_estimator/bp_estimate/bp_estimate/estimate_single_bp_vital",
            body: request
        )
    }
}

public final class BPFeatureExtractionProvider {
    private let network: DeepmediAPIClient

    public init(apiKey: String) {
        self.network = DeepmediAPIClient(apiKey: apiKey)
    }

    public func getBPFeatureExtraction(
        ppg: [Double],
        ts: [Double]
    ) async throws -> BPFeatureExtraction {
        let request = BPFeatureExtractionRequest(
            ppg: ppg,
            timestamp: ts
        )
        return try await network.post(
            urlString: "https://i40d9fg0vx.apigw.ntruss.com/bp_estimator/bp_estimate/bp_estimate/extract_bp_ft",
            body: request
        )
    }
}

public typealias BPfeatureExtractionProvider = BPFeatureExtractionProvider

final class Service {
    static let manager = Service()
    let header = DeepmediHeaderProvider()

    private init() {}
}

private struct EstimateStressFromRrRequest: Encodable {
    let rrList: [Double]
    let age: Int
    let gender: GenderType
    let k: Int
}

private struct EstimateSingleBpVitalRequest: Encodable {
    let cuff_sys: Int
    let cuff_dia: Int
    let calib_ft: [Double]
    let target_ft: [Double]
}

private struct BPFeatureExtractionRequest: Encodable {
    let ppg: [Double]
    let timestamp: [Double]
}

private struct DeepmediAPIClient {
    private let apiKey: String
    private let headerProvider: DeepmediHeaderProvider
    private let session: URLSession

    init(
        apiKey: String,
        headerProvider: DeepmediHeaderProvider = DeepmediHeaderProvider(),
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.headerProvider = headerProvider
        self.session = session
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        urlString: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let url = URL(string: urlString) else {
            throw DeepmediServiceError.invalidURL(urlString)
        }

        let headers = try await headerProvider.getHeader(
            uri: signatureURI(for: url),
            apiKey: apiKey
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestBody = try encoder.encode(body)
        request.httpBody = requestBody

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepmediServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeepmediServiceError.statusCode(httpResponse.statusCode, body)
        }

        try Self.validateAPIResult(from: data)
        return try Self.decodeResponse(ResponseBody.self, from: data)
    }

    private func signatureURI(for url: URL) -> String {
        guard let query = url.query, !query.isEmpty else {
            return url.path
        }
        return "\(url.path)?\(query)"
    }

    private static func decodeResponse<ResponseBody: Decodable>(
        _ type: ResponseBody.Type,
        from data: Data
    ) throws -> ResponseBody {
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(ResponseBody.self, from: data) {
            return direct
        }

        let envelope: DeepmediResponseEnvelope<ResponseBody>
        do {
            envelope = try decoder.decode(DeepmediResponseEnvelope<ResponseBody>.self, from: data)
        } catch {
            throw error
        }

        if let value = envelope.message ?? envelope.data ?? envelope.response {
            return value
        }

        throw DecodingError.valueNotFound(
            ResponseBody.self,
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Expected response body or response envelope"
            )
        )
    }

    private static func validateAPIResult(from data: Data) throws {
        let decoder = JSONDecoder()
        guard let status = try? decoder.decode(DeepmediAPIStatus.self, from: data),
              let result = status.result,
              result != 200 else {
            return
        }

        throw DeepmediServiceError.apiResult(
            result,
            status.messageText ?? "unknown api error"
        )
    }
}

private struct DeepmediAPIStatus: Decodable {
    let result: Int?
    let messageText: String?

    private enum CodingKeys: String, CodingKey {
        case result
        case message
    }

    private enum MessageCodingKeys: String, CodingKey {
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = try container.decodeIfPresent(Int.self, forKey: .result)

        if let text = try? container.decodeIfPresent(String.self, forKey: .message) {
            self.messageText = text
        } else if let nested = try? container.nestedContainer(keyedBy: MessageCodingKeys.self, forKey: .message) {
            self.messageText = try nested.decodeIfPresent(String.self, forKey: .message)
        } else {
            self.messageText = nil
        }
    }
}

private struct DeepmediResponseEnvelope<T: Decodable>: Decodable {
    let message: T?
    let data: T?
    let response: T?

    private enum CodingKeys: String, CodingKey {
        case message
        case data
        case response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try? container.decodeIfPresent(T.self, forKey: .message)
        self.data = try? container.decodeIfPresent(T.self, forKey: .data)
        self.response = try? container.decodeIfPresent(T.self, forKey: .response)
    }
}
