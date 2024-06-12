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
    
    enum spo2Error: Error {
        case spo2Err(e: String), `nil`
    }
    
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
            ppgHealthURI = "/face_health_estimate/v1/calculate_face_ppg_dr_bp",
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
    }
    
    func userBreathFromChest(
        secretKey: String,
        apiKey: String,
        data: URL,
        completion: @escaping((AFError?) -> ())
    ) {
        
        let chestBaseURL = "https://siigjmw19n.apigw.ntruss.com",
            chestBaseURI = "/face_health_estimate/v1/calculate_chest_resp"
        
        let header = header.v2Header(
            method: .post,
            uri: chestBaseURI,
            secretKey: secretKey,
            apiKey: apiKey
        )
        
        AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(data, withName: "data")
            },
            to: chestBaseURL + chestBaseURI,
            method: .post,
            headers: header
        ).responseDecodable(of: ChestBreathResult.self) { response in
            switch response.result {
            case .success(let res):
                guard res.result == 200 else { return print("multi ppg stress result return") }
                let response = res.message
                print("chest bresth response : ", response)
                self.recordModel.breath = Int(Double(response.respiRate)?.rounded(.toNearestOrAwayFromZero) ?? 0.0) ?? 0
                completion(nil)
            case .failure(let err):
                print("chest breath err \(err)")
                completion(err)
            }
        }
    }
    
//    func userBreath(
//        accPath: URL,
//        gyroPath: URL,
//        header: HTTPHeaders,
//        completion: @escaping((String) -> ())
//    ) {
//        AF.upload(
//            multipartFormData: { multipartFormData in
//                multipartFormData.append(accPath,
//                                         withName: "acc")
//                multipartFormData.append(gyroPath,
//                                         withName: "gyro")
//            },
//            to: url,
//            method: .post,
//            headers: header
//        )
//        .responseDecodable(of: BreathResult.self) { response in
//            switch response.result {
//            case .success(let res):
//                guard res.result == 200 else { return print("multi ppg stress result return") }
//                let response = res.message
//                print("breath response : ", response)
//                completion(String(response.meanRespiratoryRate))
//            case .failure(let err):
//                print("breath err \(err)")
//                completion("breath err")
//            }
//        }
//    }
    
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
        
        let url = cardioRiskBaseURL + cardioRiskBaseURI
        
        AF.request(
            url,
            method: .post,
            headers: header.v2Header(
                method: .post,
                uri: cardioRiskBaseURI,
                secretKey: secretKey,
                apiKey: apiKey
            )
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
    }
    
    func spo2(
        red: [Float],
        blue: [Float],
        hr: Int,
        completion: @escaping((AFError?) -> ())
    ) {
        let avgRed = average(red),
            avgBlue = average(blue)
        
        let stdevRed = stdev(red, avgRed),
            stdevBlue = stdev(blue, avgBlue)
        
        let varRed = sqrt(stdevRed / Float(red.count - 1)),
            varBlue = sqrt(stdevBlue / Float(blue.count - 1))
        
        let R = (varRed / avgRed) / (varBlue / avgBlue),
            spo2 = Int(100 - (5 * R))
        
        if ((spo2 < 80 || spo2 > 99) || (hr < 45 || hr > 200)) {
            print("ragne get out")
            completion(Service.spo2Error.spo2Err(e: "Spo2 Error").asAFError(orFailWith: "Spo2 Error"))
        } else {
            self.recordModel.spo2 = spo2
            completion(nil)
        }
    }
    
    private func average(
        _ arr: [Float]
    ) -> Float {
        guard arr.count > 0 else {
            print("arr count zero")
            return 0
        }
        return arr.reduce(0, +) / Float(arr.count)
    }
    
    private func stdev(
        _ arr : [Float],
        _ avg : Float
    ) -> Float {
        let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0)}.reduce(0, +)
        return sqrt(sumOfSquaredAvgDiff / Float(arr.count))
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

struct ChestBreathResult: Decodable {
    let message: ChestBreathRate
    let result: Int
}

struct ChestBreathRate: Decodable {
    let respiRate: String
}

struct BreathResult: Decodable {
    let message: BreathRate
    let result: Int
}

struct BreathRate: Decodable {
    let meanRespiratoryRate: Double
    
    enum CodingKeys: String, CodingKey {
        case meanRespiratoryRate = "Mean_respiratory_rate"
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
