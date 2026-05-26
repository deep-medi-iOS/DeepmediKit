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
    
    let camera = CameraDeviceController()
    
    var fingerMeasureKit: FingerKit? = FingerKit()
    let fingerMeasureKitModel = FingerKitConfiguration()
    
    let preview = CameraPreviewView()
    let previousButton = UIButton().then { b in
        b.setTitle("Previous", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = .black
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.completionMethod()
        guard let fingerMeasureKit else { return }
        
        self.camera.initalized(
            part: .finger,
            delegate:fingerMeasureKit,
            session: session,
            captureDevice: captureDevice
        )
        self.fingerMeasureKitModel.setMeasurementDataCount(900)
        self.fingerMeasureKitModel.doMeasurementBreath(false)
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
        
        self.setupUI()
        
//        DispatchQueue.main.async {
            self.fingerMeasureKit?.startSession()
//        }
    }

    deinit {
        fingerMeasureKit?.releaseSession()
    }
    
    override func viewDidLayoutSubviews() {
        preview.setup(
            layer: previewLayer,
            frame: preview.frame,
            useCornerRadius: true
        )
    }
    
    @objc func prev() {
        self.fingerMeasureKit?.releaseSession()
        self.fingerMeasureKit = nil
        self.dismiss(animated: true)
    }
    
    func completionMethod() {
        fingerMeasureKit?.measuredValue { value in
            print("value: \(value)")
        }
        
        fingerMeasureKit?.countMeasurementedData { count in
            print("count: \(count)")
        }
        
        fingerMeasureKit?.stopMeasurement { isStop in
            if isStop {
                self.fingerMeasureKit?.stopSession()
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
                        self.fingerMeasureKit?.startSession()
                    }
                }
                alertVC.addAction(action)
                self.present(alertVC, animated: false)
            } else {
                print("stop measurement: \(isStop)")
            }
        }
        
        fingerMeasureKit?.finishedMeasurement { success, rgbPath, accPath, gyroPath in
            print("finger rgb path:",  rgbPath)
            print("finger acc path:",  accPath)
            print("finger gyro pPath:", gyroPath)
            if success {
                DispatchQueue.main.async {
                    self.fingerMeasureKit?.releaseSession()
                    self.fingerMeasureKit = nil
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
