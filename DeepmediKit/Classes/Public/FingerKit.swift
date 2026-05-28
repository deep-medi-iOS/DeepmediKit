//
//  FingerKit.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import CoreMotion
import AVKit
import RxSwift
import RxCocoa

open class FingerKit: NSObject {
    public enum StopStatus: String {
        case noTap
        case flipDevice
        case notThing
    }

    internal let bag = DisposeBag()
    internal let measurementFileWriter = MeasurementFileWriter()
    internal let measurementState = MeasurementState()
    internal let notiGenerator = UINotificationFeedbackGenerator()

    internal let model = ConfigurationStore.shared
    internal let cameraSessionManager = CameraSessionManager.shared

    internal var tap: [MeasurementState.FingerStatus] = []
    internal var noTap: [MeasurementState.FingerStatus] = []
    internal var stopMeasureStatus: [MeasurementState.FingerStatus] = []

    internal var framesPerSecond: Double = 60
    internal var measurementTimer = Timer()
    internal var chartTimer = Timer()
    internal var motionManager = CMMotionManager()

    internal let limitTapCount = 30
    internal var chartData: [Float] = []

    internal var sigR: [Float] = []
    internal var sigB: [Float] = []
    internal var sigG: [Float] = []
    internal var totalData: [(Double, Float, Float, Float)] = []

    internal var accXData: [Float] = []
    internal var accYData: [Float] = []
    internal var accZData: [Float] = []
    internal var accData: [(Double, Float, Float, Float)] = []

    internal var gyroXData: [Float] = []
    internal var gyroYData: [Float] = []
    internal var gyroZData: [Float] = []
    internal var gyroData: [(Double, Float, Float, Float)] = []

    internal var isComplete = false
    internal var isCollectingData = false
    internal var didEmitCompletion = false
    internal var isTorchEnabled = false
    internal var shouldKeepTorchOn = false
    internal var torchRetryCount = 0
    internal var torchRetryWorkItem: DispatchWorkItem?
    internal let maxTorchRetryCount = 8
    internal var torchWasDisabledByFlip = false

    public override init() {
        super.init()
        setIdleTimerDisabled(true)
        if let openCVstr = OpenCVWrapper.openCVVersionString() {
            print("[++\(#fileID):\(#line)]- opencv version:", openCVstr)
        }
        measurementRGBfromFinger()
        measurementState.bindFingerTap()
    }

    deinit {
        stopMeasurementPipeline()
        cameraSessionManager.clearVideoOutputDelegate(.finger, self)
        setIdleTimerDisabled(false)
        print("[++\(#fileID)] deinit")
    }

    internal func setIdleTimerDisabled(_ disabled: Bool) {
        let apply = {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    internal func startMeasurementPipeline() {
        isComplete = false
        isCollectingData = false
        didEmitCompletion = false
        isTorchEnabled = false
        torchWasDisabledByFlip = false
        shouldKeepTorchOn = true
        torchRetryCount = 0
        cancelTorchRetry()
        measurementTimer.invalidate()
        chartTimer.invalidate()
        startAccelerometerUpdates()
        startGyroscopeUpdates()
        startDeviceMotionUpdates()
    }

    internal func prepareMeasurement() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            self.cameraSessionManager.useSession().startRunning()
            self.ensureTorchOnAfterStart()
        }
    }

    internal func stopMeasurementPipeline() {
        isComplete = true
        isCollectingData = false
        torchWasDisabledByFlip = false
        shouldKeepTorchOn = false
        cancelTorchRetry()
        measurementTimer.invalidate()
        chartTimer.invalidate()
        if model.measurePart == .finger {
            cameraSessionManager.setUpCaptureDevice(.autoExpose)
            cameraSessionManager.useSession().stopRunning()
        }
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopDeviceMotionUpdates()
        if model.measurePart == .finger {
            setTorch(enabled: false)
        }
        isTorchEnabled = false
        resetMeasurementElements()
    }

    internal func resetMeasurementElements() {
        measurementTimer.invalidate()
        chartTimer.invalidate()
        initRGBData()
        initAccData()
        initGyroData()
        tap.removeAll()
        noTap.removeAll()
        stopMeasureStatus.removeAll()
    }

    internal func setTorch(enabled: Bool) {
        if !enabled {
            shouldKeepTorchOn = false
            cancelTorchRetry()
        }
        if cameraSessionManager.setTorchMode(enabled: enabled) {
            isTorchEnabled = enabled
            if enabled {
                torchRetryCount = 0
                cancelTorchRetry()
            }
        }
    }

    internal func ensureTorchOnAfterStart() {
        refreshTorchState()
        shouldKeepTorchOn = true
        guard !isTorchEnabled else {
            return
        }
        setTorch(enabled: true)
        refreshTorchState()
        guard !isTorchEnabled else {
            return
        }
        retryTorchOn()
    }

    internal func retryTorchOn() {
        refreshTorchState()
        guard shouldKeepTorchOn, !isTorchEnabled else {
            return
        }
        guard torchRetryWorkItem == nil, torchRetryCount < maxTorchRetryCount else {
            return
        }

        torchRetryCount += 1
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.shouldKeepTorchOn, !self.isTorchEnabled else { return }
            self.setTorch(enabled: true)
            self.refreshTorchState()
            if !self.isTorchEnabled {
                self.torchRetryWorkItem = nil
                self.retryTorchOn()
            }
        }
        torchRetryWorkItem = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    internal func cancelTorchRetry() {
        torchRetryWorkItem?.cancel()
        torchRetryWorkItem = nil
    }

    internal func refreshTorchState() {
        isTorchEnabled = cameraSessionManager.isTorchOn()
    }

    internal func startAccelerometerUpdates() {
        motionManager.accelerometerUpdateInterval = 1 / 100
        guard let operationQueue = OperationQueue.current else {
            print("acc operation queue return")
            return
        }
        motionManager.startAccelerometerUpdates(to: operationQueue) { [weak self] acc, err in
            self?.collectAccelemeterData(acc, err)
        }
    }

    internal func startGyroscopeUpdates() {
        motionManager.gyroUpdateInterval = 1 / 100
        guard let operationQueue = OperationQueue.current else {
            print("gyro operation queue return")
            return
        }
        motionManager.startGyroUpdates(to: operationQueue) { [weak self] gyro, err in
            self?.collectGyroscopeData(gyro, err)
        }
    }

    internal func startDeviceMotionUpdates() {
        guard let operationQueue = OperationQueue.current, motionManager.isDeviceMotionAvailable else {
            print("deviceMotion operation queue return")
            return
        }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: operationQueue) { [weak self] motion, _ in
            guard let self, let motion else {
                print("motion return")
                return
            }
            let roll = motion.attitude.roll
            let back = roll < -2.0 || roll > 2.0
            let forward = !back

            self.measurementState.inputAccZBack.onNext(back)
            self.measurementState.inputAccZForward.onNext(forward)
        }
    }

    internal func measurementRGBfromFinger() {
        measurementState.outputFingerStatus
            .observe(on: MainScheduler.instance)
            .asDriver(onErrorJustReturn: .noTap)
            .drive(onNext: { [weak self] status in
                guard let self else { return }
                self.measurementState.checkStopStatus(status)
                let tapWindowLimit = self.limitTapCount * max(self.model.limitTapTime, 3)
                if status == .tap && self.tap.count <= tapWindowLimit {
                    if self.tap.count == 30 && !self.isComplete {
                        self.startChartUpdateTimer()
                        self.cameraSessionManager.setUpCaptureDevice(.locked)
                    }
                    self.tap.append(.tap)
                    self.noTap.removeAll()
                    self.stopMeasureStatus.removeAll()
                } else if status == .noTap {
                    self.noTap.append(.noTap)
                } else if status == .back || status == .flip {
                    self.stopMeasureStatus.append(status)
                }

                switch status {
                case .tap:
                    self.ensureTorchOnAfterStart()
                    self.refreshTorchState()
                    if self.isTorchEnabled {
                        self.torchWasDisabledByFlip = false
                    }
                    guard !self.isComplete else {
                        return
                    }
                    if self.tap.count == self.limitTapCount / 2 {
                        self.measurementState.measurementStop.onNext(false)
                    }
                    if self.tap.count >= (self.limitTapCount * self.model.limitTapTime),
                       !self.isCollectingData {
                        self.beginCountBasedMeasurement()
                    }
                case .noTap:
                    if self.torchWasDisabledByFlip {
                        self.ensureTorchOnAfterStart()
                        self.refreshTorchState()
                        if self.isTorchEnabled {
                            self.torchWasDisabledByFlip = false
                        }
                    }
                    guard self.tap.count >= 15, self.noTap.count == self.limitTapCount else {
                        return
                    }
                    self.resetMeasurementElements()
                    self.isCollectingData = false
                    self.measurementState.measurementStop.onNext(true)
                case .back, .flip:
                    self.refreshTorchState()
                    if self.isTorchEnabled {
                        self.setTorch(enabled: false)
                        self.torchWasDisabledByFlip = true
                    }
                    guard self.stopMeasureStatus.count >= 30 else {
                        return
                    }
                    self.resetMeasurementElements()
                    self.isCollectingData = false
                    self.measurementState.measurementStop.onNext(true)
                }
            })
            .disposed(by: bag)
    }

    internal func beginCountBasedMeasurement() {
        isCollectingData = true
        didEmitCompletion = false
        initRGBData()
        initAccData()
        initGyroData()

        measurementTimer.invalidate()
        measurementTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.finishMeasurementIfNeeded()
        }
    }

    internal func finishMeasurementIfNeeded() {
        guard isCollectingData, !didEmitCompletion else {
            return
        }
        measurementState.measurementCount.onNext(sigR.count)
        if totalData.count >= model.measurementFingerDataCount {
            completeMeasurement()
        }
    }

    internal func completeMeasurement() {
        guard !didEmitCompletion else {
            return
        }
        didEmitCompletion = true
        isCollectingData = false
        measurementTimer.invalidate()

        let completion = measurementState.measurementComplete
        let rgbFilePath = measurementState.rgbFilePath
        let accFilePath = measurementState.accFilePath
        let gyroFilePath = measurementState.gyroFilePath

        guard let rgbPath = measurementFileWriter.make(data: .rgb, dataSet: totalData) else {
            completion.onNext(false)
            rgbFilePath.onNext(URL(fileURLWithPath: "there is not rgb path"))
            accFilePath.onNext(URL(fileURLWithPath: "there is not acc path"))
            gyroFilePath.onNext(URL(fileURLWithPath: "there is not gyro path"))
            stopMeasurementPipeline()
            return
        }

        notiGenerator.notificationOccurred(.success)
        if model.breathMeasurement {
            if let accPath = measurementFileWriter.make(data: .acc, dataSet: accData),
               let gyroPath = measurementFileWriter.make(data: .gyro, dataSet: gyroData) {
                completion.onNext(true)
                rgbFilePath.onNext(rgbPath)
                accFilePath.onNext(accPath)
                gyroFilePath.onNext(gyroPath)
            } else {
                completion.onNext(false)
                rgbFilePath.onNext(URL(fileURLWithPath: "there is not rgb path"))
                accFilePath.onNext(URL(fileURLWithPath: "there is not acc path"))
                gyroFilePath.onNext(URL(fileURLWithPath: "there is not gyro path"))
            }
        } else {
            completion.onNext(true)
            rgbFilePath.onNext(rgbPath)
            accFilePath.onNext(URL(fileURLWithPath: "there is not acc path"))
            gyroFilePath.onNext(URL(fileURLWithPath: "there is not gyro path"))
        }

        stopMeasurementPipeline()
    }
}

