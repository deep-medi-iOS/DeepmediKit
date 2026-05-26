//
//  MeasurementState.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

internal final class MeasurementState {
    enum FingerStatus {
        case flip
        case back
        case noTap
        case tap
    }

    // MARK: Shared/Finger input streams
    let inputAccZForward = PublishSubject<Bool>()
    let inputAccZBack = PublishSubject<Bool>()
    let inputFingerTap = PublishSubject<Bool>()
    let inputFilteringGvalue = PublishSubject<Double>()

    // MARK: Shared output streams
    let acc = PublishRelay<FaceKit.Acceleration>()
    let gyro = PublishRelay<FaceKit.Gyroscope>()
    let measurementStop = BehaviorSubject<Bool>(value: true)
    let secondRemaining = PublishSubject<Int>()
    let measurementComplete = PublishSubject<Bool>()
    let rgbFilePath = PublishSubject<URL>()
    let accFilePath = PublishSubject<URL>()
    let gyroFilePath = PublishSubject<URL>()

    // MARK: Finger output stream
    let outputFingerStatus = PublishSubject<FingerStatus>()
    var stoppedByNotTap = false
    var stoppedByFlipingDevice = false
    

    // MARK: Face output streams
    let checkRealFace = BehaviorSubject(value: false)
    let resultHeatlInfo = PublishSubject<[String: Any]>()
    let resultCardioRisk = PublishSubject<[String: Any]>()
    let healthCareInfoResult = PublishSubject<[String: Any]>()
    let captureImage = PublishSubject<(screen: UIImage?, crop: UIImage?)>()
    let timeStamp = PublishSubject<[Double]>()
    let sigR = PublishSubject<[Float]>()
    let sigG = PublishSubject<[Float]>()
    let sigB = PublishSubject<[Float]>()
    let measurementCount = PublishSubject<Int>()
    let headAnglesRelay = BehaviorRelay<FaceKit.HeaderAngles?>(
        value: FaceKit.HeaderAngles(pitch: 0.0, yaw: 0.0, roll: 0.0)
    )
    let yMean = PublishSubject<Float>()
    let metaData = BehaviorRelay<FaceKit.Metadata>(
        value: FaceKit.Metadata(
            iso: 0.0,
            exposureMode: "",
            focusMode: "",
            whiteBalanceMode: ""
        )
    )

    func bindFingerTap() {
        _ = Observable
            .combineLatest(inputAccZForward, inputAccZBack, inputFingerTap)
            .observe(on: MainScheduler.instance)
            .map { [weak self] forward, back, tap in
                self?.resolveFingerStatus(forward: forward, back: back, tap: tap) ?? .noTap
            }
            .bind(to: outputFingerStatus)
    }

    func checkStopStatus(_ status: FingerStatus) {
        switch status {
        case .tap:
            stoppedByNotTap = false
            stoppedByFlipingDevice = false
        case .noTap:
            stoppedByNotTap = true
            stoppedByFlipingDevice = false
        case .back, .flip:
            stoppedByNotTap = false
            stoppedByFlipingDevice = true
        }
    }

    private func resolveFingerStatus(forward: Bool, back: Bool, tap: Bool) -> FingerStatus {
        if forward, !back, tap {
            return .tap
        }
        if forward, !back, !tap {
            return .noTap
        }
        if !forward, back, tap {
            return .back
        }
        return .flip
    }
}
