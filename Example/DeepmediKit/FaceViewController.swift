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
    
    let leftTimeLabel = UILabel().then { l in
        l.font = UIFont.systemFont(ofSize: 30)
    }
    
    let checkLabel = UILabel().then { l in
        l.font = UIFont.systemFont(ofSize: 50)
        l.layer.cornerRadius = 5
        l.clipsToBounds = true
    }
    
    let temp = UIView()
    let face = UIImageView().then { v in
        v.contentMode = .scaleAspectFit
    }
    let chest = UIImageView().then { v in
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
        faceMeasureKitModel.setMeasurementTime(30)
        faceMeasureKitModel.setWindowSecond(15)
        faceMeasureKitModel.setOverlappingSecond(2)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        self.setupUI()
        
        self.faceMeasureKit.startSession()
    }
    
    override func viewDidLayoutSubviews() {
        preview.setup(
            layer: previewLayer,
            frame: preview.frame,
            useCornerRadius: true
        )

        faceMeasureKitModel.injectingRecognitionAreaView(
            faceRecognitionAreaView
        )
    }

    func completionMethod() {
        faceMeasureKit.checkRealFace { check in
            print("face is real: \(check)")
            if check {
                self.checkLabel.text = "Real"
                self.checkLabel.backgroundColor = .green
            } else {
                self.checkLabel.text = "Not Real"
                self.checkLabel.backgroundColor = .red
            }
        }
        
        faceMeasureKit.measurementCompleteRatio { ratio in
            print("complete ratio: \(ratio)")
        }

        faceMeasureKit.timesLeft { second in
            print("second: \(second)")
            self.leftTimeLabel.text = "\(second)"
        }
        
        faceMeasureKit.stopMeasurement { isStop in
            print("face detect is stop: \(isStop)")
        }
        
        faceMeasureKit.finishedMeasurement { (face, chest) in
            let (faceRes, facePath) = face
            let (chestRes, chestPath) = chest
            if faceRes && chestRes {
                print("face path", facePath)
                print("chest path", chestPath)
                let faceHeader = self.header.v2Header(
                    method: .post,
                    uri: "face uri",
                    secretKey: "secret key",
                    apiKey: "api key"
                )
                let chestHeader = self.header.v2Header(
                    method: .post,
                    uri: "chest uri",
                    secretKey: "secret key",
                    apiKey: "api key"
                )
                self.faceMeasureKit.stopSession()
            } else {
                print("error")
            }
        }
    }

    func setupUI() {
        let width: CGFloat = 220,//UIScreen.main.bounds.width * 0.8,
            height: CGFloat = 220//UIScreen.main.bounds.height * 0.8
        
        self.view.addSubview(preview)
        self.view.addSubview(faceRecognitionAreaView)
        self.view.addSubview(leftTimeLabel)
        self.view.addSubview(checkLabel)
        self.view.addSubview(previousButton)
        
        self.view.addSubview(temp)
        self.view.addSubview(face)
        self.view.addSubview(chest)
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        faceRecognitionAreaView.translatesAutoresizingMaskIntoConstraints = false
        leftTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        checkLabel.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        
        face.translatesAutoresizingMaskIntoConstraints = false
        chest.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            preview.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            preview.topAnchor.constraint(equalTo: view.topAnchor, constant: height * 0.2),
            preview.widthAnchor.constraint(equalToConstant: width),// * 0.8),
            preview.heightAnchor.constraint(equalToConstant: width)// * 0.8)
        ])

        NSLayoutConstraint.activate([
            faceRecognitionAreaView.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            faceRecognitionAreaView.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
            faceRecognitionAreaView.widthAnchor.constraint(equalToConstant: width),// * 0.8),
            faceRecognitionAreaView.heightAnchor.constraint(equalToConstant: width)// * 0.8),
        ])
        
//        NSLayoutConstraint.activate([
//            preview.topAnchor.constraint(equalTo: self.view.topAnchor),
//            preview.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
//            preview.widthAnchor.constraint(equalToConstant: width),
//            preview.heightAnchor.constraint(equalToConstant: height)
//        ])
//
//        NSLayoutConstraint.activate([
//            faceRecognitionAreaView.topAnchor.constraint(equalTo: preview.topAnchor, constant: height * 0.2),
//            faceRecognitionAreaView.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
//            faceRecognitionAreaView.widthAnchor.constraint(equalToConstant: width * 0.7),
//            faceRecognitionAreaView.heightAnchor.constraint(equalToConstant: width * 0.7),
//        ])
        
        
        NSLayoutConstraint.activate([
            face.bottomAnchor.constraint(equalTo: chest.topAnchor),
            face.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            face.widthAnchor.constraint(equalToConstant: width * 0.4),
            face.heightAnchor.constraint(equalToConstant: width * 0.4)
        ])
        
        NSLayoutConstraint.activate([
            chest.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chest.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chest.widthAnchor.constraint(equalToConstant: width * 0.4),
            chest.heightAnchor.constraint(equalToConstant: width * 0.4)
        ])
        
        NSLayoutConstraint.activate([
            checkLabel.topAnchor.constraint(equalTo: faceRecognitionAreaView.bottomAnchor, constant: 5),
            checkLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        NSLayoutConstraint.activate([
            leftTimeLabel.topAnchor.constraint(equalTo: checkLabel.bottomAnchor, constant: 5),
            leftTimeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
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
        self.dismiss(animated: true) {
            self.faceMeasureKit.stopSession()
        }
    }
}
