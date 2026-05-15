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

    let camera = CameraDeviceController()
    
    var faceMeasureKit: FaceKit? = FaceKit()
    let faceMeasureKitModel = FaceKitConfiguration()

    let preview = CameraPreviewView()
    let previousButton = UIButton().then { b in
        b.setTitle("Previous", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .black
    }
    
    let tempView = UIView()
   
    let isoLabel = UILabel().then { l in
        l.backgroundColor = .black
        l.textColor = .white
    }
    
    let countLabel = UILabel().then { l in
        l.backgroundColor = .black
        l.textColor = .white
    }
    
    let captureImageView = UIImageView().then { v in
        v.contentMode = .scaleAspectFit
    }
    let cropImageView = UIImageView().then { v in
        v.contentMode = .scaleAspectFit
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        completionMethod()
        
        guard let faceMeasureKit else { return }
        camera.initalized(
            delegate: faceMeasureKit,
            session: session,
            captureDevice: captureDevice
        )
        faceMeasureKitModel.setMeasurementDataCount(450)
        faceMeasureKitModel.setPrepareTime(0)
        faceMeasureKitModel.willUseFaceRecognitionArea(true)
        faceMeasureKitModel.willCheckRealFace(false)
        faceMeasureKitModel.setFaceAngle(5)//얼굴 움직임 제한 각도
        faceMeasureKitModel.setStatbleRatio(0.05)//얼굴위치 제한 비율
        faceMeasureKitModel.setStableFrameCount(3)//안정상태 프레임수 조절
        faceMeasureKitModel.setBaselineAngle(10)//안정상태시 얼굴제한 각도
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        setupUI()

        faceMeasureKit.startSession()
    }

    deinit {
        faceMeasureKit?.releaseSession()
        print("[++\(#fileID):\(#line)]- vc deinit ")
    }
    
    override func viewDidLayoutSubviews() {
        preview.setup(
            layer: previewLayer,
            frame: preview.frame
        )

        faceMeasureKitModel.injectingRecognitionAreaView(faceRecognitionAreaView)
    }

    func completionMethod() {
        faceMeasureKit?.checkRealFace { check in
//            if check {
//                self.tempView.backgroundColor = .green
//            } else {
//                self.tempView.backgroundColor = .red
//            }
        }
        
        faceMeasureKit?.captureDeviceMode { [weak self] metaData in
            guard let self else { return }
            self.isoLabel.text = "\(metaData.iso)"
        }
        
        faceMeasureKit?.collectDataCount { [weak self] count in
            guard let self else { return }
            self.countLabel.text = "\(count)"
        }

        faceMeasureKit?.captureImage { [weak self] capture in
            guard let self else { return }
            if let screen = capture.screen,
               let crop = capture.face {
                self.captureImageView.image = screen
                self.cropImageView.image = crop
            } else {
                self.captureImageView.image = UIImage()
                self.cropImageView.image = UIImage()
            }
            
        }
        
        faceMeasureKit?.timesLeft { times in
            print("left prepare time : ", times)
        }
        
        faceMeasureKit?.stopMeasurement { [weak self] stop in
            guard let self else { return }
            print("stop state: \(stop)")
            if !stop {
                self.tempView.backgroundColor = .green
            } else {
                self.tempView.backgroundColor = .red
            }
        }
        
        faceMeasureKit?.finishedMeasurement(for: .all) { [weak self] result in
            guard let self else { return }
            if case let .filePath(result, path) = result {
                if result {
                    print("file path: \(path)")
                } else {
                    print("result is failed")
                }
            } else if case let .rawData(result, dataSet) = result {
                if result {
                    let ts = dataSet.ts,
                        sigR = dataSet.sigR,
                        sigB = dataSet.sigG,
                        sigG = dataSet.sigB
                    
                    if ts.count > 0
                        && sigR.count > 0
                        && sigG.count > 0
                        && sigB.count > 0 {
                        print("data set: \((ts.count, sigR.count, sigB.count, sigG.count))")
                    } else {
                        print("data error")
                    }
                }
            } else if case let .all(result, path, dataSet) = result {
                let ts = dataSet.ts
                let sigR = dataSet.sigR
                let sigG = dataSet.sigG
                let sigB = dataSet.sigB
                
                print("data set: \((ts.count, sigR.count, sigB.count, sigG.count))")
            } else {
                print("finish error")
            }
            self.faceMeasureKit?.releaseSession()
            self.faceMeasureKit = nil
        }
    }

    func setupUI() {
        let width = UIScreen.main.bounds.width,// * 0.8,
            height = UIScreen.main.bounds.height// * 0.8
        
        self.view.addSubview(preview)
        self.view.addSubview(faceRecognitionAreaView)
        self.view.addSubview(previousButton)
        self.view.addSubview(tempView)
        self.view.addSubview(isoLabel)
        self.view.addSubview(countLabel)
        self.view.addSubview(captureImageView)
        self.view.addSubview(cropImageView)
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        faceRecognitionAreaView.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        tempView.translatesAutoresizingMaskIntoConstraints = false
        isoLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        captureImageView.translatesAutoresizingMaskIntoConstraints = false
        cropImageView.translatesAutoresizingMaskIntoConstraints = false
        
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
            isoLabel.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 80),
            isoLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            isoLabel.widthAnchor.constraint(equalToConstant: width * 0.3),
            isoLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        NSLayoutConstraint.activate([
            countLabel.bottomAnchor.constraint(equalTo: previousButton.topAnchor, constant: -20),
            countLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: width * 0.3),
            countLabel.heightAnchor.constraint(equalToConstant: 50)
        ])

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
            captureImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            captureImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            captureImageView.widthAnchor.constraint(equalToConstant: width * 0.3),
            captureImageView.heightAnchor.constraint(equalToConstant: width * 0.3)
        ])
        NSLayoutConstraint.activate([
            cropImageView.leadingAnchor.constraint(equalTo: captureImageView.trailingAnchor),
            cropImageView.topAnchor.constraint(equalTo: captureImageView.topAnchor),
            cropImageView.widthAnchor.constraint(equalToConstant: width * 0.3),
            cropImageView.heightAnchor.constraint(equalToConstant: width * 0.3)
        ])
    }
    
    @objc func prev() {
        self.faceMeasureKit?.releaseSession()
        self.faceMeasureKit = nil
        self.dismiss(animated: true)
    }
}
