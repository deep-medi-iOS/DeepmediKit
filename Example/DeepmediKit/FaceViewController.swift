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

    // Example 화면에서 현재 로드된 SDK 버전을 바로 확인한다.
    let sdkVersionLabel = UILabel().then { l in
        l.backgroundColor = .black
        l.textColor = .white
        l.font = .systemFont(ofSize: 12)
        l.textAlignment = .center
    }
    
    let captureImageView = UIImageView().then { v in
        v.contentMode = .scaleAspectFit
    }
    let cropImageView = UIImageView().then { v in
        v.contentMode = .scaleAspectFit
    }

    let loadingView = UIView().then { view in
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.isHidden = true
    }

    let spinner = UIActivityIndicatorView(
        activityIndicatorStyle: .large
    ).then { spinner in
        spinner.color = .white
        spinner.hidesWhenStopped = true
        spinner.accessibilityLabel = "측정 결과 분석 중"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        sdkVersionLabel.text = "DeepmediKit SDK \(DeepmediKitSDK.version)"
        completionMethod()

        guard let faceMeasureKit else { return }
        print("[++\(#fileID):\(#line)]- FaceKit TFLite ready: \(faceMeasureKit.tfliteReady), message: \(faceMeasureKit.tfliteInitMessage)")
        print("[++\(#fileID):\(#line)]- DeepmediKit SDK \(DeepmediKitSDK.version)")

        camera.initalized(
            part: .face,
            delegate: faceMeasureKit,
            session: session,
            captureDevice: captureDevice
        )
        faceMeasureKitModel.setMeasurementDataCount(451)//측정개수
        faceMeasureKitModel.setPrepareTime(0)//측정 전 준비시간
        faceMeasureKitModel.willUseFaceRecognitionArea(true)//얼굴인식구역 사용
        faceMeasureKitModel.willUseSubFaceRecognitionArea(true)//내부 얼굴인식구역 사용
        faceMeasureKitModel.willCheckRealFace(false)//실제얼굴인지 확인
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

        faceMeasureKit?.coreInferenceState { [weak self] isRunning in
            guard let self else { return }
            self.loadingView.isHidden = !isRunning
            if isRunning {
                self.spinner.startAnimating()
            } else {
                self.spinner.stopAnimating()
            }
        }

        faceMeasureKit?.coreMetrics { [weak self] physMorphNet  in
            guard let self else { return }
            guard physMorphNet.binPath != nil, physMorphNet.metrics.ppg.count != 0 else {
                return
            }
            Task { [weak self] in
                await self?.requestVitalEstimates(from: physMorphNet)
            }
            self.faceMeasureKit?.releaseSession()
            self.faceMeasureKit = nil
        }
    }

    private func requestVitalEstimates(from output: FaceKit.PhysMorphNet) async {
        let apiKey = "apikey"
        let userAge = 30
        let userGender: GenderType = .male
        let cuffSys = 120
        let cuffDia = 75
        var calibrationPPG: [Double] = []

        let physicalStress: Double
        do {
            let stress = try await EstimateStressFromRrProvider(apiKey: apiKey)
                .getEstimateStressFromRr(
                    rrList: output.metrics.rrList,
                    age: userAge,
                    gender: userGender,
                    k: 1
                )
            physicalStress = stress.physicalStress
        } catch let error {
            print("estimate stress from rr api error: \(error.localizedDescription)")
            uploadFailureDiagnostic(
                failedApi: .estimateStressFromRR,
                error: error,
                output: output
            )
            return
        }

        let calibPPG: [Double]
        let targetPPG = output.metrics.ppg
        if calibrationPPG.isEmpty {
            calibrationPPG = targetPPG
            calibPPG       = targetPPG
        } else {
            calibPPG = calibrationPPG
        }

        let bp: EstimateFromRawPPGPredictBpVital
        do {
            bp = try await EstimateFromRawPPGPredict(apiKey: apiKey)
                .getEstimateFromRawPPGPredict(
                    calSys: cuffSys,
                    calDia: cuffDia,
                    calPPG: calibPPG,
                    targetPPG: targetPPG
                )
        } catch let error {
            uploadFailureDiagnostic(
                failedApi: .estimateFromRawPPGPredict,
                error: error,
                output: output
            )
            print("extract bp feature target api error: \(error.localizedDescription)")
            return
        }

        print("[++\(#fileID):\(#line)]- sys: \(bp.sys), dia: \(bp.dia)")
        print("[++\(#fileID):\(#line)]- hr: ", output.metrics.hr)//심박
        print("[++\(#fileID):\(#line)]- sdnn: ", output.metrics.sdnn)//스트레스
        print("[++\(#fileID):\(#line)]- rmssd: ", output.metrics.rmssd)//스트레스 회복력
        print("[++\(#fileID):\(#line)]- psi: ", physicalStress)//피로도
    }

    private func uploadFailureDiagnostic(
        failedApi: FailureDiagnosticFailedAPI,
        error: Error,
        output: FaceKit.PhysMorphNet
    ) {
        let debugInfo = FailureDiagnosticDebugInfo(
            failedApi: failedApi,
            error: error
        )

        if let binPath = output.binPath {
            FailureDiagnosticNCPUploader()
                .uploadBestEffort(
                    faceBinURL: binPath,
                    debugInfo: debugInfo
                )
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
        self.view.addSubview(sdkVersionLabel)
        self.view.addSubview(captureImageView)
        self.view.addSubview(cropImageView)
        self.view.addSubview(loadingView)
        loadingView.addSubview(spinner)
        
        preview.translatesAutoresizingMaskIntoConstraints = false
        faceRecognitionAreaView.translatesAutoresizingMaskIntoConstraints = false
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        tempView.translatesAutoresizingMaskIntoConstraints = false
        isoLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        sdkVersionLabel.translatesAutoresizingMaskIntoConstraints = false
        captureImageView.translatesAutoresizingMaskIntoConstraints = false
        cropImageView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        
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
            countLabel.topAnchor.constraint(equalTo: isoLabel.bottomAnchor, constant: -10),
            countLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            countLabel.widthAnchor.constraint(equalToConstant: width * 0.3),
            countLabel.heightAnchor.constraint(equalToConstant: 50)
        ])

        NSLayoutConstraint.activate([
            sdkVersionLabel.topAnchor.constraint(
                equalTo: countLabel.bottomAnchor,
                constant: -10
            ),
            sdkVersionLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            sdkVersionLabel.widthAnchor.constraint(equalToConstant: width * 0.5),
            sdkVersionLabel.heightAnchor.constraint(equalToConstant: 30)
        ])

        NSLayoutConstraint.activate(
            [
                previousButton.trailingAnchor.constraint(
                    equalTo: self.view.trailingAnchor
                ),
                previousButton.topAnchor.constraint(
                    equalTo: self.isoLabel.centerYAnchor
                ),
                previousButton.widthAnchor.constraint(equalToConstant: width * 0.25),
                previousButton.heightAnchor.constraint(equalToConstant: width * 0.25)
            ]
        )
        
        tempView.frame = CGRect(x: 0, y: 100, width: 100, height: 100)
        tempView.layer.cornerRadius = 50
        
        previousButton.layer.cornerRadius = (width * 0.25) / 2
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

        NSLayoutConstraint.activate([
            loadingView.topAnchor.constraint(equalTo: self.view.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor)
        ])
    }
    
    @objc func prev() {
        self.faceMeasureKit?.releaseSession()
        self.faceMeasureKit = nil
        self.dismiss(animated: true)
    }
}
