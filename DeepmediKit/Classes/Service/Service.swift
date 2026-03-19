//
//  Service.swift
//
//  Created by 딥메디 on 2/27/24.
//

import UIKit
import RxSwift

class Service {
    // MARK: Manager
    static let manager = Service()
    
    // MARK: Header
    private let header = Header()
    
    // MARK: Model
    private let recordModel = RecordModel.shared
    
    func facePPG(
        secretKey: String,
        apiKey: String,
        rgbPath: URL,
        age: Int,
        gender: Int,
        weight: Int?,
        height: Int?,
        _ com: @escaping((Error?) -> ())
    ) {
        let ppgHealthURL = "https://siigjmw19n.apigw.ntruss.com"
        let ppgHealthURI = "/face_health_estimate/v1/calculate_face_ppg_dr_bp_v3"
        let urlString = ppgHealthURL + ppgHealthURI
        
        Task { [weak self] in
            guard let self else { return }
            do {
                guard let url = URL(string: urlString) else {
                    throw URLError(.badURL)
                }
                
                // ✅ headers
                let headers = try await self.header.getHeader(uri: ppgHealthURI, apiKey: apiKey)
                
                // ✅ multipart body
                var builder = MultipartFormDataBuilder()
                let params: [String: String] = [
                    "age": "\(age)",
                    "gender": "\(gender)",
                    "weight": "\(weight ?? 0)",
                    "height": "\(height ?? 0)"
                ]
                
                // rgb 파일 mimeType은 실제 포맷에 맞게 조정 (예: video/mp4, application/octet-stream 등)
                let body = try builder.makeBody(
                    fileURL: rgbPath,
                    fileFieldName: "rgb",
                    mimeType: "application/octet-stream",
                    parameters: params
                )
                
                // ✅ request
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("multipart/form-data; boundary=\(builder.boundary)", forHTTPHeaderField: "Content-Type")
                
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                
                // ✅ upload
                let (data, response) = try await URLSession.shared.upload(for: request, from: body)
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw NSError(domain: "HTTP", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "status code error: \(http.statusCode)"
                    ])
                }
                
                // ✅ decode
                let res = try JSONDecoder().decode(ResultOfFacePPG.self, from: data)
                
                guard res.result == 200 else {
                    // 서버가 200 OK를 주더라도 payload.result가 실패일 수 있음
                    throw NSError(domain: "API", code: res.result, userInfo: [
                        NSLocalizedDescriptionKey: "ppg result error: \(res.result)"
                    ])
                }
                
                let msg = res.message
                self.recordModel.hr = msg.hr
                self.recordModel.sys = msg.sys
                self.recordModel.dia = msg.dia
                self.recordModel.physicalStress = msg.physicalStress
                self.recordModel.mentalStress = msg.mentalStress
                self.recordModel.af = msg.afDetect
                
                com(nil)
            } catch {
                print("facePPG error:", error.localizedDescription)
                com(error)
            }
        }
    }
    
    func cardiacRisk(
        secretKey: String,
        apiKey: String,
        gender: Int,
        age: Int,
        height: Int,
        weight: Int,
        belly: Int,
        act: Int,
        smoke: Int,
        diabetes: Int,
        sys: Int,
        dia: Int,
        _ com: @escaping((Error?) -> ())
    ) {
        let baseURL = "https://escv0giloo.apigw.ntruss.com"
        let path = "/risk_calculator/v1/cardio_risk"
        
        Task { [weak self] in
            guard let self else { return }
            do {
                var components = URLComponents(string: baseURL + path)
                components?.queryItems = [
                    .init(name: "gender", value: "\(gender)"),
                    .init(name: "age", value: "\(age)"),
                    .init(name: "height", value: "\(height)"),
                    .init(name: "weight", value: "\(weight)"),
                    .init(name: "belly", value: "\(belly)"),
                    .init(name: "act", value: "\(act)"),
                    .init(name: "smoke", value: "\(smoke)"),
                    .init(name: "diabetes", value: "\(diabetes)"),
                    .init(name: "sys", value: "\(sys)"),
                    .init(name: "dia", value: "\(dia)")
                ]
                
                guard let url = components?.url else {
                    throw URLError(.badURL)
                }
                
                // 🔥 중요: 서명에 쓰는 uri는 "path + ?query..." 형태여야 함 (기존과 동일)
                let uriForSignature = path + "?" + (components?.percentEncodedQuery ?? "")
                let headers = try await self.header.getHeader(uri: uriForSignature, apiKey: apiKey)
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw NSError(domain: "HTTP", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "status code error: \(http.statusCode)"
                    ])
                }
                
                let decoded = try JSONDecoder().decode(CardiacResult.self, from: data)
                let cvdRiskArr = self.changeDataFormat(risk: decoded.message.cvdRisk)
                self.recordModel.cardioRisk = cvdRiskArr.reduce(0, +) / Double(cvdRiskArr.count)
                
                com(nil)
            } catch {
                print("cardiacRisk error:", error.localizedDescription)
                com(error)
            }
        }
    }
    
    private func changeDataFormat(
        risk: String
    ) -> [Double] {
        risk
            .components(separatedBy: "[")[1]
            .components(separatedBy: "]")[0]
            .components(separatedBy: ", ")
            .map { num in
                Double(num) ?? 0.0
            }
    }
    
    private struct MultipartFormDataBuilder {
        let boundary: String = "Boundary-\(UUID().uuidString)"

        mutating func makeBody(
            fileURL: URL,
            fileFieldName: String,
            fileName: String? = nil,
            mimeType: String,
            parameters: [String: String]
        ) throws -> Data {
            var data = Data()

            // text params
            for (key, value) in parameters {
                data.appendString("--\(boundary)\r\n")
                data.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                data.appendString("\(value)\r\n")
            }

            // file
            let actualFileName = fileName ?? fileURL.lastPathComponent
            let fileData = try Data(contentsOf: fileURL)

            data.appendString("--\(boundary)\r\n")
            data.appendString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(actualFileName)\"\r\n")
            data.appendString("Content-Type: \(mimeType)\r\n\r\n")
            data.append(fileData)
            data.appendString("\r\n")

            data.appendString("--\(boundary)--\r\n")
            return data
        }
    }

    // MARK: - Data helper
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) {
            append(d)
        }
    }
}

struct ResultOfFacePPG: Codable {
    let message: ResultData
    let result: Int
}

struct ResultData: Codable {
    let hr: Int,
        sys: Int,
        dia: Int,
        physicalStress: Float,
        mentalStress: Float,
        afDetect: Int
    
    enum CodingKeys: String, CodingKey {
        case hr, sys, dia, mentalStress, physicalStress , afDetect = "af_detect"
    }
}

struct CardiacResult: Codable {
    let message: CardiacRisk
    let result: Int
}

struct CardiacRisk: Codable {
    let BMI: String
    let cvdRisk: String
    
    enum CodingKeys: String, CodingKey {
        case cvdRisk = "cvdrisk", BMI
    }
}
