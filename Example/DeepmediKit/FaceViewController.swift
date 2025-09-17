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

    let header = Header()
    let camera = CameraObject()
    
    let faceMeasureKit = FaceKit()
    let faceMeasureKitModel = FaceKitModel()

    let preview = CameraPreview()
    let previousButton = UIButton().then { b in
        b.setTitle("Previous", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .black
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
//        faceMeasureKitModel.setWindowSecond(15)
//        faceMeasureKitModel.setOverlappingSecond(2)
        faceMeasureKitModel.willUseFaceRecognitionArea(true)
        faceMeasureKitModel.willCheckRealFace(false)
        
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
        }
        
        faceMeasureKit.measurementCompleteRatio { ratio in
            print("complete ratio: \(ratio)")
        }

        faceMeasureKit.timesLeft { second in
            print("second: \(second)")
        }
        
        faceMeasureKit.stopMeasurement { stop in
            print("stop state: \(stop)")
        }
        
        faceMeasureKit.finishedMeasurement { (successed, path) in
            print("face measure state: \(successed)")
            print("face rbg path: \(path)")
        
            if successed {
                Task {
                    do {
                        let headers = try await self.header.getHeader(
                            uri   : "uri",
                            apiKey: "apikey"
                        )
                    } catch let error {
                        print("header error: \(error.localizedDescription)")
                    }
                }
                self.faceMeasureKit.stopSession()
            } else {
                print("error")
            }
        }
        
        faceMeasureKit.resultHealthInfo(
            secretKey: "secretKey",
            apiKey: "apikey",
            genderType: .MALE,
            age: 20,
            height: 170,
            weight: 70,
            belly: Int(),
            exerciseType: .none,
            smokeType: .none,
            diabetesType: .none
        ) { healthInfo in
            print(healthInfo)
        }
    }

    func setupUI() {
        let width = UIScreen.main.bounds.width * 0.8,
            height = UIScreen.main.bounds.height * 0.8
        
        self.view.addSubview(preview)
        self.view.addSubview(faceRecognitionAreaView)
        self.view.addSubview(previousButton)
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        faceRecognitionAreaView.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: self.view.topAnchor),
            preview.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            preview.widthAnchor.constraint(equalToConstant: width),
            preview.heightAnchor.constraint(equalToConstant: height)
        ])

        NSLayoutConstraint.activate([
            faceRecognitionAreaView.topAnchor.constraint(equalTo: preview.topAnchor, constant: height * 0.2),
            faceRecognitionAreaView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            faceRecognitionAreaView.widthAnchor.constraint(equalToConstant: width * 0.7),
            faceRecognitionAreaView.heightAnchor.constraint(equalToConstant: width * 0.7),
        ])

        NSLayoutConstraint.activate([
            previousButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            previousButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -80),
            previousButton.widthAnchor.constraint(equalToConstant: width * 0.3),
            previousButton.heightAnchor.constraint(equalToConstant: width * 0.3)
        ])

        previousButton.layer.cornerRadius = (width * 0.3) / 2
        previousButton.addTarget(
            self,
            action: #selector(prev),
            for: .touchUpInside
        )
    }
    
    @objc func prev() {
        self.faceMeasureKit.stopSession()
        self.dismiss(animated: true)
    }
}
