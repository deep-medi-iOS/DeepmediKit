//
//  MeasurementModel.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import RxSwift
import RxCocoa

class MeasurementModel {
    let acc = PublishRelay<FaceKit.Acceleration>()
    let gyro = PublishRelay<FaceKit.Gyroscope>()
    
    let secondRemaining = PublishSubject<Int>()
    let measurementCompleteRatio = PublishSubject<String>()
    let measurementStop = PublishSubject<Bool>()
    
    let checkRealFace = BehaviorSubject(value: false)
    let resultHeatlInfo = PublishSubject<[String: Any]>()
    let resultCardioRisk = PublishSubject<[String: Any]>()
    let healthCareInfoResult = PublishSubject<[String: Any]>()
    let measurementComplete = PublishSubject<Bool>()
    let captureImage = PublishSubject<(screen: UIImage?, crop: UIImage?)>()
    let rgbFilePath = PublishSubject<URL>()
    let csvFilePath = PublishSubject<URL>()
    let accFilePath = PublishSubject<URL>()
    let gyroFilePath = PublishSubject<URL>()
    let timeStamp = PublishSubject<[Double]>()
    let sigR = PublishSubject<[Float]>()
    let sigG = PublishSubject<[Float]>()
    let sigB = PublishSubject<[Float]>()
    let measurementCount = PublishSubject<Int>()
    
    let headAnglesRelay = BehaviorRelay<FaceKit.HeaderAngles?>(value: FaceKit.HeaderAngles.init(pitch: 0.0, yaw: 0.0, roll: 0.0))
    
    let yMean = PublishSubject<Float>()
    
    let metaData = BehaviorRelay<FaceKit.Metadata>(
        value: FaceKit.Metadata.init(
            iso: 0.0,
            exposureMode: "",
            focusMode: "",
            whiteBalanceMode: ""
        )
    )
}
