//
//  FaceViewController.swift
//  DeepmediKit_Example
//
//  Created by 딥메디 on 2023/06/19.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import UIKit
import AVKit
import DeepmediKit
import Alamofire

class FaceViewController: UIViewController {
    var faceRecognitionAreaView: UIView = FaceRecognitionAreaView(
        pattern: [24, 10],
        strokeColor: .white,
        lineWidth: 11.8
    )
    
    var previewLayer = AVCaptureVideoPreviewLayer()
    let session = AVCaptureSession()
    let captureDevice = AVCaptureDevice(uniqueID: "FaceCapture")

    let camera = CameraObject()
    
    let faceMeasureKit = FaceKit()
    let faceMeasureKitModel = FaceKitModel()

    let preview = CameraPreview()
    let previousButton = UIButton().then { b in
        b.setTitle("Previous", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .black
    }
    
    let tempView = UIView()
    
    let tempImageView = UIImageView().then { v in
        v.contentMode = .scaleAspectFit
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        completionMethod()
        
        camera.initalized(
            part: .face,
            delegate: faceMeasureKit,
            session: session,
            captureDevice: captureDevice
        )
        faceMeasureKitModel.setMeasurementTime(15)
        faceMeasureKitModel.setPrepareTime(3)
        faceMeasureKitModel.willUseFaceRecognitionArea(true)
        faceMeasureKitModel.willCheckRealFace(true)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        self.setupUI()

        self.faceMeasureKit.startSession()
    }
    
    override func viewDidLayoutSubviews() {
        preview.setup(
            layer: previewLayer,
            frame: preview.frame
        )

        faceMeasureKitModel.injectingRecognitionAreaView(faceRecognitionAreaView)
    }

    func completionMethod() {
        faceMeasureKit.checkRealFace { check in
            print("face is real: \(check)")
            if check {
                self.tempView.backgroundColor = .green
            } else {
                self.tempView.backgroundColor = .red
            }
        }
        
        faceMeasureKit.captureImage { img in
            print("[++\(#fileID):\(#line)]- image ")
            if let capture = img {
                self.tempImageView.image = capture
            } else {
                self.tempImageView.image = UIImage()
            }
            
        }
        
        faceMeasureKit.measurementCompleteRatio { ratio in
//            print("complete ratio: \(ratio)")
        }

        faceMeasureKit.timesLeft { second in
            print("second: \(second)")
        }
        
        faceMeasureKit.stopMeasurement { stop in
            print("stop state: \(stop)")
        }
        
        faceMeasureKit.finishedMeasurement(for: .filePath) { result in
            if case let .filePath(result, path) = result {
                if result {
                    print("file path: \(path)")
                    Task {
                        do {
//                            let header = try await self.header()
//                            let result = try await self.concurrencyEstimatePPG(
//                                header: header,
//                                file: path
//                            )
//                            print("[++\(#fileID):\(#line)]- result: ", result)
                        } catch {
                            print("error: \(error)")
                        }
                    }
                } else {
                    print("result is failed")
                }
            } else if case let .rawData(result, dataSet) = result {
                if result {
                    let ts = dataSet.0,
                        sigR = dataSet.1,
                        sigB = dataSet.2,
                        sigG = dataSet.3
                    
                    if ts.count > 0
                        && sigR.count > 0
                        && sigG.count > 0
                        && sigB.count > 0 {
                        print("data set: \(ts.count, sigR.count, sigB.count, sigG.count)")
                    } else {
                        print("data error")
                    }
                }
            } else {
                print("finish error")
            }
            self.faceMeasureKit.stopSession()
        }
    }

    func setupUI() {
        let width = UIScreen.main.bounds.width,// * 0.8,
            height = UIScreen.main.bounds.height// * 0.8
        
        self.view.addSubview(preview)
        self.view.addSubview(faceRecognitionAreaView)
        self.view.addSubview(previousButton)
        self.view.addSubview(tempView)
        self.view.addSubview(tempImageView)
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        faceRecognitionAreaView.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        tempView.translatesAutoresizingMaskIntoConstraints = false
        tempImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: self.view.topAnchor),
            preview.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            preview.widthAnchor.constraint(equalToConstant: width),
            preview.heightAnchor.constraint(equalToConstant: height)
        ])
        
        NSLayoutConstraint.activate([
            faceRecognitionAreaView.topAnchor.constraint(equalTo: preview.topAnchor, constant: height * 0.2),
            faceRecognitionAreaView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor), 
            faceRecognitionAreaView.widthAnchor.constraint(equalToConstant: (width / 390) * 230),
            faceRecognitionAreaView.heightAnchor.constraint(equalToConstant: (height / 844) * 320),
//            faceRecognitionAreaView.widthAnchor.constraint(equalToConstant: width * 0.7),
//            faceRecognitionAreaView.heightAnchor.constraint(equalToConstant: width * 0.7),
        ])
        faceRecognitionAreaView.layer.borderColor = UIColor.blue.cgColor
        faceRecognitionAreaView.layer.borderWidth = 2

        NSLayoutConstraint.activate([
            previousButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            previousButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -80),
            previousButton.widthAnchor.constraint(equalToConstant: width * 0.3),
            previousButton.heightAnchor.constraint(equalToConstant: width * 0.3)
        ])
        
        tempView.frame = CGRect(x: 0, y: 100, width: 100, height: 100)
        tempView.layer.cornerRadius = 50
        
        previousButton.layer.cornerRadius = (width * 0.3) / 2
        previousButton.addTarget(
            self,
            action: #selector(prev),
            for: .touchUpInside
        )
        
        NSLayoutConstraint.activate([
            tempImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tempImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            tempImageView.widthAnchor.constraint(equalToConstant: width * 0.3),
            tempImageView.heightAnchor.constraint(equalToConstant: width * 0.3)
        ])
    }
    
    @objc func prev() {
        self.faceMeasureKit.stopSession()
        self.dismiss(animated: true)
    }
    
    func header() async throws -> Header {
        let url = "https://y8gc8ito4a.apigw.ntruss.com/signature/v1/"
        let params = [
            "uri":    "/face_health_estimate/v1/calculate_face_ppg_dr_bp_v3",
            "method": "POST",
            "api_key": "4D5lRr2SFk3u91dBqfRWazXdp01yNQUBXJuUmeCA"
        ] as [String: Any]
        
        let headers: HTTPHeaders = [
            .contentType("application/json")
        ]
        
        let resp = await AF.request(
            url,
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            headers: headers
        )
            .serializingDecodable(Header.self).response
        
        if let afError = resp.error {
            throw EstimateErr.message(afError.localizedDescription)
        }
        
        if let statusCode = resp.response?.statusCode,
           !(200..<300).contains(statusCode) {
            throw AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode))
        } else if let value = resp.value {
            return value
        } else {
            throw EstimateErr.message("Please ensure an accurate measurement.")
        }
        return .init(signature: "", timestamp: "", accessKey: "")
    }
    
    func concurrencyEstimatePPG(
        header: Header,
        file: URL
    ) async throws -> EstimateMessage {
        let url = "https://siigjmw19n.apigw.ntruss.com/face_health_estimate/v1/calculate_face_ppg_dr_bp_v3"
        
        let params = [
            "age": 20,
            "gender": 0,
            "height": 170,
            "weight": 70
        ] as [String: Any]

        // Ensure all header values are Strings
        let headers: HTTPHeaders = [
            "x-ncp-apigw-api-key" : "4D5lRr2SFk3u91dBqfRWazXdp01yNQUBXJuUmeCA",
            "x-ncp-iam-access-key" : header.accessKey,
            "x-ncp-apigw-signature-v1": header.signature,
            "x-ncp-apigw-timestamp" : header.timestamp
        ]
        
        let resp = await AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(file, withName: "rgb")
                params.forEach { key, value in
                    multipartFormData.append("\(value)".data(using: .utf8)!, withName: key)
                }
            },
            to: url,
            method: .post,
            headers: headers
        )
        .serializingDecodable(Estimate.self)
        .response
        
        if let afError = resp.error {
            throw EstimateErr.message(afError.localizedDescription)
        }
        if let statusCode = resp.response?.statusCode,
           !(200..<300).contains(statusCode) {
            throw AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode))
        } else if let value = resp.value {
            if value.result == 200 {
                return value.message
            } else {
                throw EstimateErr.message("Please ensure an accurate measurement.")
            }
        }
        return .init(
            hr: 0,
            RMSSD: 0,
            SDNN: 0,
            rrList: [],
            preRRlist: [],
        )
    }
}

enum EstimateErr: Error {
    case message(String)
}

struct Header: Codable {
    let signature: String
    let timestamp: String
    let accessKey: String
}

struct Estimate: Codable {
    let message: EstimateMessage,
        result: Int
}

struct EstimateMessage: Codable {
    let hr: Int,
        RMSSD: Int,
        SDNN: Int,
        rrList: [Float],
        preRRlist:  [Float]
    
    enum CodingKeys: String, CodingKey {
        case rrList = "rr_list", preRRlist = "pre_rr_list"
        case hr, RMSSD, SDNN
        
    }
}
