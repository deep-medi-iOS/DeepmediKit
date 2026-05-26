//
//  FingerKitOutput.swift
//  DeepmediKit
//
//  Created by 딥메디 on 5/21/26.
//

import UIKit
import RxSwift
import RxCocoa

public extension FingerKit {
    func startSession() {
        startMeasurementPipeline()
        prepareMeasurement()
    }

    func stopSession() {
        stopMeasurementPipeline()
    }

    // 세션 종료 + delegate 해제를 통해 FingerKit 인스턴스 해제를 돕는다.
    func releaseSession() {
        stopMeasurementPipeline()
        cameraSessionManager.clearVideoOutputDelegate(.finger, self)
    }
    
    func countMeasurementedData(
        _ count: @escaping (Int) -> Void
    ) {
        measurementState.measurementCount
            .observe(on: MainScheduler.asyncInstance)
            .asDriver(onErrorJustReturn: 0)
            .drive(onNext: { value in
                count(value)
            })
            .disposed(by: bag)
    }

    /// success: Bool, rgb: URL, acc: URL, gyro: URL
    func finishedMeasurement(
        _ isSuccess: @escaping ((_ success: Bool, _ rgbPath: URL, _ accPath: URL, _ gyroPath: URL) -> Void)
    ) {
        Observable
            .combineLatest(
                measurementState.measurementComplete,
                measurementState.rgbFilePath,
                measurementState.accFilePath,
                measurementState.gyroFilePath
            )
            .observe(on: MainScheduler.instance)
            .asDriver(
                onErrorJustReturn: (
                    success: false,
                    rgbURL: URL(fileURLWithPath: ""),
                    accURL: URL(fileURLWithPath: ""),
                    gyroURL: URL(fileURLWithPath: "")
                )
            )
            .drive(onNext: { result in
                isSuccess(result.0, result.1, result.2, result.3)
            })
            .disposed(by: bag)
    }

    func stopMeasurement(
        _ isStop: @escaping ((Bool) -> Void)
    ) {
        measurementState.measurementStop
            .asDriver(onErrorJustReturn: false)
            .distinctUntilChanged()
            .drive(onNext: { stop in
                isStop(stop)
            })
            .disposed(by: bag)
    }

    func stoppedStatus() -> StopStatus {
        if measurementState.stoppedByNotTap {
            return .noTap
        }
        if measurementState.stoppedByFlipingDevice {
            return .flipDevice
        }
        return .notThing
    }

    func measuredValue(
        _ filtered: @escaping (Double) -> Void
    ) {
        measurementState.inputFilteringGvalue
            .observe(on: MainScheduler.asyncInstance)
            .asDriver(onErrorJustReturn: 0)
            .drive(onNext: { value in
                filtered(value)
            })
            .disposed(by: bag)
    }
}
