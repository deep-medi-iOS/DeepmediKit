//
//  FingerCameraFrameDelegate.swift
//  DeepmediKit
//
//  Created by 딥메디 on 5/26/26.
//

import CoreMotion


// MARK: AVCapture Delegate
extension FingerKit: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let cvimgRef = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        CVPixelBufferLockBaseAddress(cvimgRef, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(cvimgRef, CVPixelBufferLockFlags(rawValue: 0))
        }

        guard let openCVDatas = OpenCVWrapper.preccessbuffer(
            sampleBuffer,
            device: UIDevice.current.modelName
        ) else {
            print("objc casting error")
            return
        }
        guard let tap = openCVDatas[0] as? Bool else {
            print("objc bool casting error")
            return
        }
        guard let r = openCVDatas[1] as? Float,
              let g = openCVDatas[2] as? Float,
              let b = openCVDatas[3] as? Float else {
            print("objc rgb casting error")
            return
        }
        print("[++\(#fileID):\(#line)]- tap: ", tap)
        measurementState.inputFingerTap.onNext(tap)
        let timeStamp = (Date().timeIntervalSince1970 * 1_000_000).rounded()
        guard timeStamp > 100 else { return }
        guard isCollectingData else { return }
        collectRGB(timeStamp: timeStamp, r: r, g: g, b: b)
        finishMeasurementIfNeeded()
    }

    internal func startChartUpdateTimer() {
        chartTimer = Timer.scheduledTimer(
            timeInterval: 1 / framesPerSecond,
            target: self,
            selector: #selector(updatedChartData),
            userInfo: nil,
            repeats: true
        )
    }

    @objc internal func updatedChartData() {
        measurementState.inputFilteringGvalue.onNext(filter(g: chartData))
    }

    internal func filter(g: [Float]) -> Double {
        let a = [1.0, -7.30103128, 23.42566938, -43.14485924, 49.89209273, -37.09502293, 17.31790014, -4.64159393, 0.54684548]
        let b = [0.00013253, 0.0, -0.00053013, 0.0, 0.0007952, 0.0, -0.00053013, 0.0, 0.00013253]

        var x: [Double] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
        var y: [Double] = [0, 0, 0, 0, 0, 0, 0, 0, 0]
        var result = Double()

        for value in g {
            x.insert(Double(value), at: 0)
            result = ((b[0] * x[0])
                     + (b[1] * x[1])
                     + (b[2] * x[2])
                     + (b[3] * x[3])
                     + (b[4] * x[4])
                     + (b[5] * x[5])
                     + (b[6] * x[6])
                     + (b[7] * x[7])
                     + (b[8] * x[8])
                     - (a[1] * y[0])
                     - (a[2] * y[1])
                     - (a[3] * y[2])
                     - (a[4] * y[3])
                     - (a[5] * y[4])
                     - (a[6] * y[5])
                     - (a[7] * y[6])
                     - (a[8] * y[7]))
            y.insert(result, at: 0)
            x.removeLast()
            y.removeLast()
        }
        return result
    }

    internal func collectRGB(timeStamp: Double, r: Float, g: Float, b: Float) {
        chartData.append(g)
        sigR.append(r)
        sigG.append(g)
        sigB.append(b)
        totalData.append((timeStamp, r, g, b))
    }

    internal func collectAccelemeterData(_ acc: CMAccelerometerData?, _ err: Error?) {
        guard err == nil else { return }
        guard isCollectingData else { return }
        guard let accMeasureData = acc?.acceleration else { return }

        let x = Float(accMeasureData.x)
        let y = Float(accMeasureData.y)
        let z = Float(accMeasureData.z)
        let timeStamp = (Date().timeIntervalSince1970 * 1_000_000).rounded()
        guard timeStamp > 100 else { return }

        accXData.append(x)
        accYData.append(y)
        accZData.append(z)
        accData.append((timeStamp, x, y, z))
    }

    internal func collectGyroscopeData(_ gyro: CMGyroData?, _ err: Error?) {
        guard err == nil else { return }
        guard isCollectingData else { return }
        guard let gyroMeasureData = gyro?.rotationRate else { return }

        let x = Float(gyroMeasureData.x)
        let y = Float(gyroMeasureData.y)
        let z = Float(gyroMeasureData.z)
        let timeStamp = (Date().timeIntervalSince1970 * 1_000_000).rounded()
        guard timeStamp > 100 else { return }

        gyroXData.append(x)
        gyroYData.append(y)
        gyroZData.append(z)
        gyroData.append((timeStamp, x, y, z))
    }

    internal func initRGBData() {
        sigR.removeAll()
        sigG.removeAll()
        sigB.removeAll()
        totalData.removeAll()
        chartData.removeAll()
    }

    internal func initAccData() {
        accXData.removeAll()
        accYData.removeAll()
        accZData.removeAll()
        accData.removeAll()
    }

    internal func initGyroData() {
        gyroXData.removeAll()
        gyroYData.removeAll()
        gyroZData.removeAll()
        gyroData.removeAll()
    }
}
