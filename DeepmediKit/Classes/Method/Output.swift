//
//  Output.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import UIKit
import RxSwift
import RxCocoa

public extension FaceKit {
    // 세션 시작관련 정보
    func startSession() {
        measurementTime = model.faceMeasurementTime
        preparingSec    = model.prepareTime
        isTimerRunning  = false
        dispatchTimer?.cancel()
        measurementTimer.invalidate()
        prepareTimer.invalidate()
        //센서 사용
        startAccelerometer()
        startGryoscope()
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let previewLayer = self.model.previewLayer else {
                print("previewLayer is nil")
                return
            }
            self.previewLayer = previewLayer
            self.willCheckRealFace = model.willCheckRealFace
            
            if self.model.useFaceRecognitionArea,
               let faceRecognitionAreaView = self.model.faceRecognitionAreaView {
                self.useFaceRecognitionArea = self.model.useFaceRecognitionArea
                self.faceRecognitionAreaView = faceRecognitionAreaView
//                DispatchQueue.main.async {
//                    self.faceRecognitionAreaView.addSubview(self.cropView)
//                    self.faceRecognitionAreaView.addSubview(self.landMarkView)
//                    self.faceRecognitionAreaView.addSubview(self.recogView)
//                    self.faceRecognitionAreaView.addSubview(self.faceDetecView)
//                    self.faceRecognitionAreaView.addSubview(self.smallView)
//                }
            }
            self.cameraSetup.useSession().startRunning()
        }
    }
    //세션 멈춤관련 정보
    func stopSession() {
        lastFrame = nil
        cropFaceRect = nil
        
        isLeftEyeReal = false
        isRightEyeReal = false
        
        initRGBData()
        timerReset()
        antiSpoofing.initialize()
        cameraSetup.setUpCaptureDevice(.autoExpose)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.cameraSetup.useSession().stopRunning()
        }
    }
    // 결과전송 파일 URL
    func outputPath(
        _ path: @escaping((FilePath) -> ())
    ) {
        let gyroFilePath = measurementModel.gyroFilePath
        let accFilePath = measurementModel.accFilePath
        let frameDataPath = measurementModel.frameDataFilePath
        Observable.combineLatest(
            frameDataPath,
            accFilePath,
            gyroFilePath
        )
        .asObservable()
        .map { frame, acc, gyro in
            return FilePath.init(
                frameDataPath: frame,
                accelPath: acc,
                gyroPath: gyro
            )
        }
        .subscribe(onNext: { value in
            path(value)
        })
        .disposed(by: bag)
    }
    // 수집한 데이터 개수
    func collectDataCount(
        _ count: @escaping((Int) -> ())
    ) {
        let countRelay = measurementModel.measurementCount
        countRelay
            .asDriver(onErrorJustReturn: 0)
            .distinctUntilChanged(==)
            .drive(onNext: { value in
                count(value)
            })
            .disposed(by: bag)
    }
    // iso, exposureMode, focusMode, whiteBalanceMode output
    func captureDeviceMode(
        _ mode: @escaping((Metadata) -> ())
    ) {
        let metaData = measurementModel.metaData
        metaData
            .asDriver(onErrorDriveWith: .empty())
            .distinctUntilChanged(==)
            .drive(onNext: { value in
                mode(value)
            })
            .disposed(by: bag)
    }
    // 가속도 센서 output
    func acceleration(
        _ sensorData: @escaping((Acceleration) -> ())
    ) {
        let accRelay = measurementModel.acc
        accRelay
            .asDriver(onErrorJustReturn: .init(ts: 0, x: 0, y: 0, z: 0))
            .distinctUntilChanged(==)
            .drive(onNext: { value in
                sensorData(value)
            })
            .disposed(by: bag)
    }
    // 자이로 센서 output
    func gyroscope(
        _ sensorData: @escaping((Gyroscope) -> ())
    ) {
        let gyroRelay = measurementModel.gyro
        gyroRelay
            .asDriver(onErrorJustReturn: .init(ts: 0, x: 0, y: 0, z: 0))
            .distinctUntilChanged(==)
            .drive(onNext: { value in
                sensorData(value)
            })
            .disposed(by: bag)
    }
    // 얼굴 회전 output
    func pitchYawRoll(
        _ pitchYawRoll: @escaping((HeaderAngles) -> ())
    ) {
        let headAnglesRelay = measurementModel.headAnglesRelay
        headAnglesRelay
            .asDriver()
            .compactMap { $0 }
            .distinctUntilChanged(==)
            .drive(onNext: { angle in
                pitchYawRoll(HeaderAngles.init(pitch: angle.pitch, yaw: angle.yaw, roll: angle.roll))
            })
            .disposed(by: bag)
    }
    // 밝기 output
    func yMean(
        _ y: @escaping((Float) -> ())
    ) {
        let yMean = measurementModel.yMean
        yMean
            .asDriver(onErrorJustReturn: 0)
            .distinctUntilChanged(==)
            .drive(onNext: { value in
                y(value)
            })
            .disposed(by: bag)
    }
    // 실제 얼굴 확인 output
    func checkRealFace(
        _ isReal: @escaping((Bool) -> ())
    ) {
        let check = measurementModel.checkRealFace
        check
            .asDriver(onErrorJustReturn: false)
            .distinctUntilChanged()
            .drive { check in
                isReal(check)
            }
            .disposed(by: bag)
    }
    // 화면캡쳐, 화면에서 얼굴 부분 크롭 output
    func captureImage(
        _ capture: @escaping((Capture) -> ())
    ) {
        let captureImage = measurementModel.captureImage
        captureImage
            .observe(on: MainScheduler.asyncInstance)
            .asDriver(onErrorJustReturn: (screen: nil, crop: nil))
            .drive(onNext: { image in
                guard let screen = image.screen, let crop = image.crop else { return }
                capture(Capture(screen: screen, face: crop))
            })
            .disposed(by: bag)
    }
    // 측정 멈춤시 반환 output
    func stopMeasurement(
        _ isStop: @escaping((Bool) -> ())
    ) {
        let stop = self.measurementModel.measurementStop
        stop
            .asDriver(onErrorJustReturn: true)
            .distinctUntilChanged()
            .drive(onNext: { stop in
                self.notDetectFace = stop
                isStop(stop)
            })
            .disposed(by: bag)
    }
    // 측정 완료 후 output
    // filePath: rgb.txt만 전달, rawData: ts,r,g,b 배열만 전달, all: rgb.txt, ts,r,g,b 배열 모두 전달
    func finishedMeasurement(
        for kind: Result,
        _ isSuccess: @escaping(ResultSelector) -> ()
    ) {
        let completion = measurementModel.measurementComplete
        let filePath = measurementModel.rgbFilePath
        
        Observable.combineLatest(
            completion,
            filePath,
        )
        .observe(on: MainScheduler.instance)
        .asDriver(onErrorJustReturn: (false, URL(fileURLWithPath: "")))
        .drive(
            onNext: {[weak self] (res, path) in
                guard let self else { return }
                let output: ResultSelector
                let ts = timeStamp.map { $0 - (self.timeStamp.first ?? 0.0) }
                let r  = sigR
                let g  = sigG
                let b  = sigB
                switch kind {
                    case .filePath:
                        output = .filePath(result: res, path: path)
                    case .rawData:
                        output = .rawData(
                            result: res,
                            dataSet: DataSet(
                                ts: ts,
                                sigR: r,
                                sigG: g,
                                sigB: b
                            )
                        )
                case .all:
                        output = .all(
                            result: res,
                            path: path,
                            dataSet: DataSet(
                                ts: ts,
                                sigR: r,
                                sigG: g,
                                sigB: b
                            )
                        )
            }
            isSuccess(output)
        })
        .disposed(by: bag)
    }
    // 측정 완료률 전달 output
    func measurementCompleteRatio(
        _ com: @escaping((String) -> ())
    ) {
        let ratio = measurementModel.measurementCompleteRatio
        ratio
            .asDriver(onErrorJustReturn: "0%")
            .asDriver()
            .drive(onNext: { ratio in
                com(ratio)
            })
            .disposed(by: self.bag)
    }
    // 측정 완료까지 남은 시간 전달 output
    func timesLeft(
        _ com: @escaping((Int) -> ())
    ) {
        let secondRemaining = measurementModel.secondRemaining
        secondRemaining
            .asDriver(onErrorJustReturn: 0)
            .distinctUntilChanged(==)
            .drive(onNext: { remaining in
                com(remaining)
            })
            .disposed(by: bag)
    }
}
