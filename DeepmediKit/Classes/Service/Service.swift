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
    
    public func facePPG(
        secretKey: String,
        apiKey: String,
        rgbPath: URL,
        age: Int,
        gender: Int,
        weight: Int,
        height: Int,
        completion: @escaping ((Bool, AFError?) -> ())
    ) {
        let parameter = [
            "age" : age,
            "gender" : gender,
            "weight" : weight,
            "height" : height
        ] as [String : Int]
    
        let ppgHealthURL = "https://siigjmw19n.apigw.ntruss.com",
            ppgHealthURI = "/face_health_estimate/vl/calculate_face_ppg_dr_bp",
            url = ppgHealthURL + ppgHealthURI,
            header = header.v2Header(
                method: .post,
                uri: ppgHealthURI,
                secretKey: secretKey,
                apiKey: apiKey
            )
        
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
            headers: header)
        .responseDecodable(of: ResultOfFacePPG.self) { response in
            
            switch response.result {
            case .success(let res):
                
                guard res.result == 200 else { return print("ppg stress result return") }
                
                self.recordModel.hr = res.message.hr
                self.recordModel.sys = res.message.sys
                self.recordModel.dia = res.message.dia
                self.recordModel.msi = res.message.msi
                self.recordModel.psi = res.message.psi
                self.recordModel.af = res.message.afDetect == 0 ? true : false
                self.recordModel.hrGraph = res.message.hrGraph
                self.recordModel.rmssd = res.message.RMSSD
                self.recordModel.sdnn = res.message.SDNN
                
                completion(true, nil)
                
            case .failure(let err):
                completion(false, err)
                print("post stress data err: " + err.localizedDescription)
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
        result: BehaviorSubject<[String: Any]>
    ) {
        let cardiacRiskBaseURL = "https://escv0giloo.apigw.ntruss.com",
            cardiacRiskBaseURI = "/risk_calculator/v1/cardio_risk"
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
        
        let url = cardiacRiskBaseURL + cardiacRiskBaseURI
        
        AF.request(
            url,
            method: .post,
            headers: header.v2Header(
                method: .post,
                uri: cardiacRiskBaseURI,
                secretKey: secretKey,
                apiKey: apiKey
            )
        )
        .responseDecodable(of: CardiacResult.self) { response in
            switch response.result {
            case .success(let res):
                self.recordModel.cardioRisk = self.changeDataFormat(
                    risk: res.message.cvdRisk
                )
                result.onNext(
                    [
                        "hr": self.recordModel.hr,
                        "msi": self.recordModel.msi,
                        "psi": self.recordModel.psi,
                        "af": self.recordModel.af,
                        "bp": (self.recordModel.sys, self.recordModel.dia),
                        "cardioRisk": self.recordModel.cardioRisk,
                    ]
                )
                
            case .failure(let err):
                print(err.localizedDescription)
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
        psi: Float,
        msi: Float,
        hrGraph: [Float],
        afDetect: Int,
        RMSSD: Int,
        SDNN: Int
    
    enum CodingKeys: String, CodingKey {
        case hr, msi, psi, sys, dia, afDetect = "af_detect",
             RMSSD, SDNN, hrGraph = "hr_graph"
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
