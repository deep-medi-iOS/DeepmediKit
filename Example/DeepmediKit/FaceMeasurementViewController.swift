//
//  ExampleViewController.swift
//  DeepmediKit_Example
//
//  Created by 딥메디 on 2/12/26.
//  Copyright © 2026 CocoaPods. All rights reserved.
//

import UIKit
import DeepmediKit
import Alamofire
import Then
import SnapKit

class FaceMeasurementViewController: UIViewController {
    var previewLayer = AVCaptureVideoPreviewLayer()
    let session = AVCaptureSession()
    let captureDevice = AVCaptureDevice(uniqueID: "FaceCapture")

    let camera = CameraObject()
    
    let faceMeasureKit = FaceKit()
    let faceMeasureKitModel = FaceKitModel()

    let preview = CameraPreview()
    
    // MARK: - Properties
    private let faceRecognitionAreaView = UIView()
    
    private let previewContainerView = UIView().then {
        $0.backgroundColor = .black
    }
    
    private let previewImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFill
        $0.clipsToBounds = true
    }
    
    private let headerView = UIView().then {
        $0.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    }
    
    private let faceDetectedLabel = UILabel().then {
        $0.text = "FACE DETECTED"
        $0.textColor = .white
        $0.font = .systemFont(ofSize: 14, weight: .semibold)
    }
    
    private let checkmarkImageView = UIImageView().then {
        $0.image = UIImage(systemName: "checkmark")
        $0.tintColor = .green
        $0.contentMode = .scaleAspectFit
    }
    
    private let leftInfoStackView = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
        $0.alignment = .leading
        $0.backgroundColor = .black
    }
    
    private let rightInfoStackView = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 12
        $0.alignment = .leading
        $0.backgroundColor = .black
    }
    
    private let footerView = UIView().then {
        $0.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    }
    
    private let timerLabel = UILabel().then {
        $0.textColor = .white
        $0.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
    }
    
    private let framesLabel = UILabel().then {
        $0.textColor = .systemPink
        $0.font = .systemFont(ofSize: 16, weight: .semibold)
    }
    
    private let separatorLabel = UILabel().then {
        $0.text = "|"
        $0.textColor = .gray
        $0.font = .systemFont(ofSize: 16, weight: .regular)
    }
    
    // Info Items
    private lazy var isoItem = InfoItemView(title: "ISO")
    private lazy var aeItem = InfoItemView(title: "AE")
    private lazy var afItem = InfoItemView(title: "AF")
    private lazy var awbItem = InfoItemView(title: "AWB")
    
    private lazy var yItem = InfoItemView(title: "LUX")
    private lazy var yawItem = InfoItemView(title: "YAW")
    private lazy var pitchItem = InfoItemView(title: "PITCH")
    private lazy var rollItem = InfoItemView(title: "ROLL")
    private lazy var accelXItem = InfoItemView(title: "ACCEL X")
    private lazy var accelYItem = InfoItemView(title: "ACCEL Y")
    private lazy var accelZItem = InfoItemView(title: "ACCEL Z")
    private lazy var gyroXItem = InfoItemView(title: "GYRO X")
    private lazy var gyroYItem = InfoItemView(title: "GYRO Y")
    private lazy var gyroZItem = InfoItemView(title: "GYRO Z")
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    
        completionMethod()
        
        camera.initalized(
            delegate: faceMeasureKit,
            session: session,
            captureDevice: captureDevice
        )
        faceMeasureKitModel.setMeasurementTime(15)
        faceMeasureKitModel.setPrepareTime(0)
        faceMeasureKitModel.willUseFaceRecognitionArea(false)
        faceMeasureKitModel.willCheckRealFace(false)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        setupUI()

        faceMeasureKit.startSession()
    }

    deinit {
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
        faceMeasureKit.captureDeviceMode {[weak self] metaData in
            guard let self = self else { return }
            self.isoItem.setValue("\(metaData.iso)")
            self.aeItem.setValue(metaData.exposureMode)
            self.afItem.setValue(metaData.focusMode)
            self.awbItem.setValue(metaData.whiteBalanceMode)
        }
        
        faceMeasureKit.pitchYawRoll {[weak self] pitchYawRoll in
            guard let self = self else { return }
            let pitch = (pitchYawRoll.pitch * 10).rounded() / 10
            let yaw = (pitchYawRoll.yaw * 10).rounded() / 10
            let roll = (pitchYawRoll.roll * 10).rounded() / 10
            self.pitchItem.setValue("\(pitch)")
            self.yawItem.setValue("\(yaw)")
            self.rollItem.setValue("\(roll)")
        }
        
        faceMeasureKit.yMean {[weak self] yMean in
            guard let self = self else { return }
            let y = (yMean * 100).rounded() / 100
            self.yItem.setValue("\(y)")
        }
        
        faceMeasureKit.acceleration {[weak self] acc in
            guard let self = self else { return }
            let x = (acc.x * 100).rounded() / 100
            let y = (acc.y * 100).rounded() / 100
            let z = (acc.z * 100).rounded() / 100
            self.accelXItem.setValue("\(x)")
            self.accelYItem.setValue("\(y)")
            self.accelZItem.setValue("\(z)")
        }
        
        faceMeasureKit.gyroscope {[weak self] gyro in
            guard let self = self else { return }
            let x = (gyro.x * 100).rounded() / 100
            let y = (gyro.y * 100).rounded() / 100
            let z = (gyro.z * 100).rounded() / 100
            self.gyroXItem.setValue("\(x)")
            self.gyroYItem.setValue("\(y)")
            self.gyroZItem.setValue("\(z)")
        }
        
        faceMeasureKit.collectDataCount {[weak self] count in
            guard let self = self else { return }
            self.framesLabel.text = "\(count) FRAMES"
        }
        
        faceMeasureKit.timesLeft {[weak self] second in
            guard let self = self else { return }
            self.timerLabel.text = "0:\(second)"
        }
        
        faceMeasureKit.stopMeasurement {[weak self] stop in
            guard let self = self else { return }
            checkmarkImageView.tintColor = stop ? .red : .green
        }
        
        faceMeasureKit.finishedMeasurement(for: .all) { result in
            if case let .all(result, path, dataSet) = result {
                let ts = dataSet.ts
                let sigR = dataSet.sigR
                let sigG = dataSet.sigG
                let sigB = dataSet.sigB
                
                
            } else {
                print("finish error")
            }
            self.faceMeasureKit.stopSession()
        }
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(preview)
        view.addSubview(faceRecognitionAreaView)
        view.addSubview(headerView)
        headerView.addSubview(faceDetectedLabel)
        headerView.addSubview(checkmarkImageView)
        
        view.addSubview(leftInfoStackView)
        view.addSubview(rightInfoStackView)
        
        view.addSubview(footerView)
        footerView.addSubview(timerLabel)
        footerView.addSubview(separatorLabel)
        footerView.addSubview(framesLabel)
        
        // Add info items to stacks
        [
            isoItem,
            aeItem,
            afItem,
            awbItem
        ].forEach {
            leftInfoStackView.addArrangedSubview($0)
        }
        
        [
            yawItem,
            pitchItem,
            rollItem,
            accelXItem,
            accelYItem,
            accelZItem,
            gyroXItem,
            gyroYItem,
            gyroZItem,
            yItem,
        ].forEach {
            rightInfoStackView.addArrangedSubview($0)
        }
    }
    
    private func setupConstraints() {
        preview.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        headerView.snp.makeConstraints {
            $0.top.left.right.equalToSuperview()
            $0.height.equalTo(100)
        }
        
        faceDetectedLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-20)
        }
        
        checkmarkImageView.snp.makeConstraints {
            $0.centerY.equalTo(faceDetectedLabel)
            $0.left.equalTo(faceDetectedLabel.snp.right).offset(8)
            $0.width.height.equalTo(16)
        }
        
        leftInfoStackView.snp.makeConstraints {
            $0.left.equalToSuperview().offset(16)
            $0.top.equalTo(headerView.snp.bottom).offset(16)
            $0.width.equalTo(80)
        }
        
        rightInfoStackView.snp.makeConstraints {
            $0.right.equalToSuperview().offset(-16)
            $0.top.equalTo(headerView.snp.bottom).offset(16)
            $0.width.equalTo(80)
        }
        
        footerView.snp.makeConstraints {
            $0.left.right.bottom.equalToSuperview()
            $0.height.equalTo(80)
        }
        
        timerLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview().offset(-50)
        }
        
        separatorLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview()
        }
        
        framesLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.centerX.equalToSuperview().offset(70)
        }
        
        faceRecognitionAreaView.snp.makeConstraints { make in
            make.top.equalTo(preview).offset(UIScreen.main.bounds.height * 0.2)
            make.centerX.equalToSuperview()
            make.width.equalTo((UIScreen.main.bounds.width / 390) * 230)
            make.height.equalTo((UIScreen.main.bounds.height / 844) * 320)
        }
//        faceRecognitionAreaView.layer.borderColor = UIColor.blue.cgColor
//        faceRecognitionAreaView.layer.borderWidth = 2
    }
}

class InfoItemView: UIView {
    
    private let titleLabel = UILabel().then {
        $0.textColor = .gray
        $0.font = .systemFont(ofSize: 10, weight: .medium)
    }
    
    private let valueLabel = UILabel().then {
        $0.textColor = .white
        $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }
    
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(valueLabel)
        
        titleLabel.snp.makeConstraints {
            $0.top.left.right.equalToSuperview()
        }
        
        valueLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.left.right.bottom.equalToSuperview()
        }
    }
    
    func setValue(_ value: String) {
        self.valueLabel.text = value
    }
}
