//
//  MotionData.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation
import CoreMotion

// MARK: ACC, GYRO
extension FaceKit {
    private enum MotionDataType {
        case accelerometer
        case gyroscope
    }
    //가속도 센서 시작
    internal func startAccelerometer() {
        motionManager.accelerometerUpdateInterval = 1 / 50
        guard OperationQueue.current != nil else {
            print("acc operation queue return")
            return
        }
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self else { return }
            self.collectMotionData(data?.acceleration, type: .accelerometer, error: error)
        }
    }
    //자이로 센서 시작
    internal func startGryoscope() {
        motionManager.gyroUpdateInterval = 1 / 50
        guard OperationQueue.current != nil else {
            print("acc operation queue return")
            return
        }
        motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self else { return }
            self.collectMotionData(data?.rotationRate, type: .gyroscope, error: error)
        }
    }
    
    private func collectMotionData<T: MotionDataProtocol>(
        _ data: T?,
        type: MotionDataType,
        error: Error?
    ) {
        if let err = error {
            print("\(type) error: \(err.localizedDescription)")
            return
        }
        
        guard let motionData = data else {
            print("\(type) data is nil")
            return
        }
        
        let x = motionData.x
        let y = motionData.y
        let z = motionData.z
        let ts = (Date().timeIntervalSince1970 * 1000000).rounded()
        
        switch type {
            case .accelerometer:
                let accData = Acceleration.init(ts: ts, x: x, y: y, z: z)
                acc.append(accData)
                measurementState.acc.accept(accData)
            case .gyroscope:
                let gyroData = Gyroscope.init(ts: ts, x: x, y: y, z: z)
                gyro.append(gyroData)
                measurementState.gyro.accept(gyroData)
        }
    }
}

protocol MotionDataProtocol {
    var x: Double { get }
    var y: Double { get }
    var z: Double { get }
}
extension CMAcceleration: MotionDataProtocol {}
extension CMRotationRate: MotionDataProtocol {}
