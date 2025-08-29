//
//  MeasurementModel.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import RxSwift

class MeasurementModel {
    public enum status {
        case flip, back, noTap, tap
    }
    
    //input
    let inputAccZforward = PublishSubject<Bool>(),
        inputAccZback = PublishSubject<Bool>(),
        inputFingerTap = PublishSubject<Bool>(),
        inputFilteringGvalue = PublishSubject<Double>()
    
    //output
    //공용
    let secondRemaining = PublishSubject<Int>()
    let measurementCompleteRatio = PublishSubject<String>()
    let measurementStop = PublishSubject<Bool>()
    
    //손가락 전용
    let outputFingerStatus = PublishSubject<MeasurementModel.status>()
    let fingerMeasurementComplete = BehaviorSubject(value: (false, URL(string: ""), URL(string: ""), URL(string: "")))
    
    var stoppedByNotTap = false
    var stoppedByFlipingDevice = false
    
    //얼굴 전용
    let checkRealFace = BehaviorSubject(value: false)
    let resultHeatlInfo = PublishSubject<[String: Any]>()
    let resultCardioRisk = PublishSubject<[String: Any]>()
    let healthCareInfoResult = PublishSubject<[String: Any]>()
//    let faceMeasurementComplete = BehaviorSubject(value: (false, URL(string: "")))
//    let chestMeasurementComplete = BehaviorSubject(value: (false, URL(string: "")))
    let measurementComplete = PublishSubject<Bool>()
    let captureImage = PublishSubject<UIImage?>()
    let rgbFilePath = PublishSubject<URL>()
    let timeStamp = PublishSubject<[Double]>()
    let sigR = PublishSubject<[Float]>()
    let sigG = PublishSubject<[Float]>()
    let sigB = PublishSubject<[Float]>()
    
    //bind
    func bindFingerTap() {
        _ = Observable
            .combineLatest(self.inputAccZforward,
                           self.inputAccZback,
                           self.inputFingerTap)
            .observe(on: MainScheduler.instance)
            .asObservable()
            .map {
                self.measurePossible(
                    forward: $0,
                    back: $1,
                    tap: $2
                )
            }
            .bind(to: self.outputFingerStatus)
    }
    
    func measurePossible(
        forward: Bool,
        back: Bool,
        tap: Bool
    ) -> MeasurementModel.status {
        var result = status.noTap
        if forward, !back, tap {
            result = .tap
        } else if forward, !back, !tap {
            result = .noTap
        } else if !forward, back, tap {
            result = .back
        } else if !forward, back, !tap {
            result = .flip
        }
        return result
    }
    
    func checkStopStatus(
        _ status: MeasurementModel.status
    ) {
        switch status {
        case .tap:
            self.stoppedByNotTap = false
            self.stoppedByFlipingDevice = false
        case .noTap:
            self.stoppedByNotTap = true
            self.stoppedByFlipingDevice = false
        default:
            self.stoppedByNotTap = false
            self.stoppedByFlipingDevice = true
        }
    }
}
