//
//  FaceKit.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import MLKitVision
import MLKitFaceDetection
import AVKit
import CoreImage
import RxSwift
import RxCocoa
import CoreMotion
import Then

public class FaceKit: NSObject {
    public enum Result {
        case filePath, rawData, all
    }
    public enum ResultSelector {
        case filePath(result: Bool, path: URL)
        case rawData(result: Bool, dataSet: DataSet)
        case all(result: Bool, path: URL, dataSet: DataSet)
    }
    public struct DataSet {
        public let ts: [Double],
                   sigR: [Float],
                   sigG: [Float],
                   sigB: [Float]
    }
    public struct HeaderAngles: Equatable {
        public let pitch: CGFloat
        public let yaw:   CGFloat
        public let roll:  CGFloat
    }
    public struct Metadata: Equatable {
        public let iso: Float
        //AE
        public let exposureMode: String
//        public let exposureOffset: Float
        //AF
        public let focusMode: String
        //AWB
        public let whiteBalanceMode: String
    }
    public struct Capture {
        public let screen: UIImage?
        public let face: UIImage?
        public init(screen: UIImage?, face: UIImage?) {
            self.screen = screen
            self.face = face
        }
    }
    
    public struct Acceleration: Equatable {
        let ts: Double
        public let x: Double
        public let y: Double
        public let z: Double
    }
    
    public struct Gyroscope: Equatable {
        let ts: Double
        public let x: Double
        public let y: Double
        public let z: Double
    }
    
    public struct FilePath {
        public let frameDataPath: URL,
                   accelPath: URL,
                   gyroPath: URL
    }
    
    struct FrameData {
        let timestampUS: Double
        let width: Int
        let height: Int
        let brightness: Float
        let faceYaw: Double
        let facePitch: Double
        let faceRoll: Double
        let iso: Float
        let aeState: String
        let awbState: String
        let afState: String
    }
    
    enum MeasurementErr: Error {
        case message(String)
    }
    
    internal let bag = DisposeBag()
    
    internal let document = Document(), measurementModel = MeasurementModel()
    
    internal let model       = Model.shared,
                 cameraSetup = CameraSetup.shared
    
    internal var lastFrame: CMSampleBuffer?,
                 gCIContext: CIContext?,
                 cropFaceRect: CGRect?,
                 cropChestRect: CGRect?
    
// MARK: Property 
    internal var preparingSec = Int(), // 얼굴을 인식하고 준비하는 시간
               prepareTimer = Timer(),
               measurementTime = Double(), // 측정하는 시간
               measurementTimer = Timer(),
               motionManager = CMMotionManager()
    
    internal var previewLayer = AVCaptureVideoPreviewLayer(),
                faceRecognitionAreaView = UIView()
    
    internal var notDetectFace = true
    internal var isLeftEyeReal = false,
                 isRightEyeReal = false
    
    internal var willCheckRealFace = false
    
    internal var lastValue: Int? = nil
    internal var lastImage: UIImage?
    internal var cropFaceImage: UIImage?
    internal var dispatchTimer: DispatchSourceTimer?
    internal var isTimerRunning = false
    internal var useFaceRecognitionArea = false
    
    internal var timeStamp: [Double] = []
    internal var sigR: [Float] = []
    internal var sigB: [Float] = []
    internal var sigG: [Float] = []
    internal var tempG: [Float] = []
    internal var totalData: [(Double, Float, Float, Float)] = []
    
    internal var acc: [Acceleration] = []
    internal var gyro: [Gyroscope] = []
    
    internal var bytesArray: [[UInt8]] = []
    internal var frameDataArr: [FrameData] = []
    
    public override init() {
        super.init()
        print("[++\(#fileID):\(#line)]- init ")
        UIApplication.shared.isIdleTimerDisabled = true //측정중 화면 자동잠금을 막기 위해 설정
    }
    
    deinit {
        print("[++\(#fileID)] deinit ")
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    internal var cropView = UIImageView().then { imv in
        imv.contentMode = .scaleAspectFit
    }
    internal var landMarkView = UIImageView().then { imv in
        imv.contentMode = .scaleAspectFit
    }
    
    internal let antiSpoofing = Antispoofing()
    internal let cropBuffer   = CropBuffer()
    internal let orientation  = Orientation()
    internal var recogView = UIView()
    internal var faceDetecView = UIView()
    internal var smallView = UIView()

    // MARK: 측정완료
    internal func saveMeasurementOutputs() {
        measurementModel.measurementStop.onNext(false)
        
        let secondRemaining          = measurementModel.secondRemaining,
//            measurementCompleteRatio = measurementModel.measurementCompleteRatio,
            measurementComplete      = measurementModel.measurementComplete,
            rgbFilePath              = measurementModel.rgbFilePath,
            frameFilePath            = measurementModel.frameDataFilePath,
            accFilePath              = measurementModel.accFilePath,
            gyroFilePath             = measurementModel.gyroFilePath,
            measurementCount         = measurementModel.measurementCount

        initRGBData()
        preparingSec    = model.prepareTime
        measurementTime = model.faceMeasurementTime
        
        dispatchTimer = DispatchSource.makeTimerSource()
        dispatchTimer?.schedule(deadline: .now(), repeating: 0.01)
        dispatchTimer?.setEventHandler { [weak self] in
            guard let self = self, self.isLeftEyeReal && self.isRightEyeReal else {
                self?.antiSpoofing.initialize()
                self?.lastValue = nil
                self?.isTimerRunning = false
                self?.dispatchTimer?.cancel()
                return
            }
            self.isTimerRunning = true
//            if let ratio = self.completionRate(
//                second: self.measurementTime
//            ) {
//                measurementCompleteRatio.onNext("\(ratio)%")
//            }
//            if 0.55 <= self.measurementTime && self.measurementTime <= 0.59 {
//                self.screenCapture()
//            }
            secondRemaining.onNext(Int(self.measurementTime))
            measurementCount.onNext(sigR.count)
            self.measurementTime -= 0.01
//            if self.measurementTime <= 0.0 {
            if self.sigR.count == 450 {
                if let rgbPath = self.document.make(
                    data: .rgb,
                    dataSet: totalData
                ),
                   let frameDataPath = self.document.saveFrameCSV(
                    data: frameDataArr
                   ),
                   let accCSV = self.document.saveSensorCSV(
                    fileName: "sensor_accelerometer.csv",
                    data: acc,
                    timestamp: \.ts, x: \.x, y: \.y, z: \.z
                   ),
                   let gyroCSV = self.document.saveSensorCSV(
                    fileName: "sensor_gyroscope.csv",
                    data: gyro,
                    timestamp: \.ts, x: \.x, y: \.y, z: \.z
                   ) {
//                    guard let dataBin = self.document.makeBin(
//                        dataSet: totalData,
//                        bytesArr: bytesArray
//                    ) else {
//                        print("byte to bin error")
//                        return
//                    }
                    measurementComplete.onNext(true)
                    rgbFilePath.onNext(rgbPath)
                    frameFilePath.onNext(frameDataPath)
                    accFilePath.onNext(accCSV)
                    gyroFilePath.onNext(gyroCSV)
                } else {
                    measurementComplete.onNext(false)
                    rgbFilePath.onNext(URL(fileURLWithPath: ""))
                    frameFilePath.onNext(URL(fileURLWithPath: ""))
                    accFilePath.onNext(URL(fileURLWithPath: ""))
                    gyroFilePath.onNext(URL(fileURLWithPath: ""))
                }
                self.dispatchTimer?.cancel()
                self.isTimerRunning = false
                self.motionManager.stopAccelerometerUpdates()
                self.motionManager.stopGyroUpdates()
            }
        }
        dispatchTimer?.resume()
    }
    
    private func completionRate(
        second: Double
    ) -> Int? {
        let newValue = Int((100.0 - (second / model.faceMeasurementTime) * 100.0).rounded(.awayFromZero))
        let ratio = newValue != lastValue ? newValue : nil
        lastValue = newValue
        if let r = ratio {
            return r
        }
        return nil
    }
}
