//
//  FingerViewController.swift
//  DeepmediKit_Example
//
//  Created by 딥메디 on 2023/06/19.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import UIKit
import AVKit
import DeepmediKit

class FingerViewController: UIViewController {
    
    var previewLayer = AVCaptureVideoPreviewLayer()
    let session = AVCaptureSession()
    let captureDevice = AVCaptureDevice(uniqueID: "FingerCapture")
    
    let header = Header()
    let camera = CameraObject()
    
    let fingerMeasureKit = FingerKit()
    let fingerMeasureKitModel = FingerKitModel()
    
    let preview = CameraPreview()
    let previousButton = UIButton().then { b in
        b.setTitle("Previous", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .black
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.completionMethod()
        
        self.camera.initalized(
            part: .finger,
            delegate:fingerMeasureKit,
            session: session,
            captureDevice: captureDevice
        )
        self.fingerMeasureKitModel.setMeasurementTime(30)
        self.fingerMeasureKitModel.doMeasurementBreath(true)
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        
        self.setupUI()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.fingerMeasureKit.startSession()
        }
    }
    
    override func viewDidLayoutSubviews() {
        preview.setup(
            layer: previewLayer,
            frame: preview.frame,
            useCornerRadius: true
        )
    }
    
    @objc func prev() {
        self.fingerMeasureKit.stopSession()
        self.dismiss(animated: true)
    }
    
    func completionMethod() {
        fingerMeasureKit.measuredValue { value in
            print("value: \(value)")
        }
        
        fingerMeasureKit.measurementCompleteRatio { ratio in
            print("complete ratio: \(ratio)")
        }
        
        fingerMeasureKit.timesLeft { time in
            print("left time: \(time)")
        }
        
        fingerMeasureKit.stopMeasurement { isStop in
            if isStop {
                self.fingerMeasureKit.stopSession()
                let alertVC = UIAlertController(
                    title: "Stop",
                    message: "",
                    preferredStyle: .alert
                )
                let action = UIAlertAction(
                    title: "cancel",
                    style: .default
                ) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.fingerMeasureKit.startSession()
                    }
                }
                alertVC.addAction(action)
                self.present(alertVC, animated: false)
            } else {
                print("stop measurement: \(isStop)")
            }
        }
        
        fingerMeasureKit.finishedMeasurement { success, rgbPath, accPath, gyroPath in
            print("finger rgb path:", rgbPath)
            print("finger acc path:", accPath)
            print("finger gyr pPath:", gyroPath)
            if success {
                let header = self.header.v2Header(method: .post,
                                                  uri: "uri",
                                                  secretKey: "secretKey",
                                                  apiKey: "apiKey")
                
                DispatchQueue.global(qos: .background).async {
                    self.fingerMeasureKit.stopSession()
                }
            } else {
                print("error")
            }
        }
    }
    
    func setupUI() {
        let width = UIScreen.main.bounds.width * 0.8,
            height = UIScreen.main.bounds.height * 0.8
        
        self.view.addSubview(preview)
        self.view.addSubview(previousButton)
        preview.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: self.view.topAnchor),
            preview.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            preview.widthAnchor.constraint(equalToConstant: width),
            preview.heightAnchor.constraint(equalToConstant: width)
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
}
