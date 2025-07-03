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
        
        faceMeasureKit.finishedMeasurement { (successed, dataSet) in
            print("face measure state: \(successed)")
//            print("fac measure data set: \(dataSet)")
            
            if successed {
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
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        faceRecognitionAreaView.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        tempView.translatesAutoresizingMaskIntoConstraints = false
        
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
    }
    
    @objc func prev() {
        self.faceMeasureKit.stopSession()
        self.dismiss(animated: true)
    }
}
