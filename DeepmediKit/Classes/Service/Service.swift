//
//  Service.swift
//  Alamofire
//
//  Created by 딥메디 on 2/27/24.
//

import UIKit
import RxSwift
import Alamofire

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
        weight: Int,
        height: Int,
        _ com: @escaping((AFError?) -> ())
    ) {
        let parameter = [
            "age" : age,
            "gender" : gender,
            "weight" : weight,
            "height" : height
        ] as [String : Int]
        
        let ppgHealthURL = "https://siigjmw19n.apigw.ntruss.com",
            ppgHealthURI = "/face_health_estimate/v1/calculate_face_ppg_dr_bp_v3",
            url = ppgHealthURL + ppgHealthURI

        Task {[weak self] in
            guard let self = self else { return }
            do {
                let element = try await self.header.getHeader(uri: ppgHealthURI, apiKey: apiKey)
                let headers: HTTPHeaders = [
                    "x-ncp-apigw-api-key"      : apiKey,
                    "x-ncp-apigw-timestamp"    : element.timestamp,
                    "x-ncp-iam-access-key"     : element.accessKey,
                    "x-ncp-apigw-signature-v1" : element.signature
                ]
                AF.upload(
                    multipartFormData: { multipartFormData in
                        multipartFormData.append(rgbPath, withName: "rgb")
                        for (key, value) in parameter {
                            multipartFormData.append("\(value)".data(using: .utf8)!,
                                                     withName: key)
                        }
                    },
                    to: url,
                    method: .post,
                    headers: headers
                )
                .responseDecodable(of: ResultOfFacePPG.self) { response in
                    
                    switch response.result {
                    case .success(let res):

                        guard res.result == 200 else { return print("ppg stress result return") }
                        let response = res.message
                        self.recordModel.hr = response.hr
                        self.recordModel.sys = response.sys
                        self.recordModel.dia = response.dia
                        self.recordModel.physicalStress = response.physicalStress
                        self.recordModel.mentalStress =   response.mentalStress
                        self.recordModel.af = response.afDetect
                        
                        com(nil)
                    case .failure(let err):
                        print("post stress data err: " + err.localizedDescription)
                        com(err)
                    }
                }
            } catch {
                
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
        _ com: @escaping((AFError?) -> ())
    ) {
        let cardioRiskBaseURL = "https://escv0giloo.apigw.ntruss.com",
            cardioRiskBaseURI = "/risk_calculator/v1/cardio_risk"
            .appending("?gender=")
            .appending("\(gender)")
            .appending("&age=")
            .appending("\(age)")
            .appending("&height=")
            .appending("\(height)")
            .appending("&weight=")
            .appending("\(weight)")
            .appending("&belly=")
            .appending("\(belly)")
            .appending("&act=")
            .appending("\(act)")
            .appending("&smoke=")
            .appending("\(smoke)")
            .appending("&diabetes=")
            .appending("\(diabetes)")
            .appending("&sys=")
            .appending("\(sys)")
            .appending("&dia=")
            .appending("\(dia)")
            
        Task {[weak self] in
            guard let self = self else { return }
            do {
                let url = cardioRiskBaseURL + cardioRiskBaseURI
                let element = try await self.header.getHeader(uri: cardioRiskBaseURI, apiKey: apiKey)
                let headers: HTTPHeaders = [
                    "x-ncp-apigw-api-key"      : apiKey,
                    "x-ncp-apigw-timestamp"    : element.timestamp,
                    "x-ncp-iam-access-key"     : element.accessKey,
                    "x-ncp-apigw-signature-v1" : element.signature
                ]
                AF.request(
                    url,
                    method: .post,
                    headers: headers
                )
                .responseDecodable(of: CardiacResult.self) { response in
                    switch response.result {
                    case .success(let res):
                        let cvdRiskArr = self.changeDataFormat(
                            risk: res.message.cvdRisk
                        )
                        self.recordModel.cardioRisk = cvdRiskArr.reduce(0, +) / Double(cvdRiskArr.count)
                        com(nil)

                    case .failure(let err):
                        print("cardio risk fail " + err.localizedDescription)
                        com(err)
                    }
                }
            } catch {
                
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
