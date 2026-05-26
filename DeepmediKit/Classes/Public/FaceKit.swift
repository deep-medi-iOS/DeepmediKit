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
    
    public struct LightingChangeDetectorResult {
        public let changed: Bool
        public let rawDerivative: Float
        public let smoothedDerivative: Float
        public let brightness: Float
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
    
    internal let measurementFileWriter = MeasurementFileWriter(),
                 measurementState = MeasurementState(),
                 lightingChangeDetector = LightingChangeDetector()
    
    internal let model       = ConfigurationStore.shared,
                 cameraSessionManager = CameraSessionManager.shared
    
    internal var lastFrame: CMSampleBuffer?,
                 gCIContext: CIContext?,
                 cropFaceRect: CGRect?,
                 cropChestRect: CGRect?
    
// MARK: Property 
    internal var preparingSec = Int(), // 얼굴을 인식하고 준비하는 시간
                 prepareTimer = Timer(),
                 measurementDataCount: Int = 450, //총 측정개수
                 measurementTimer = Timer(),
                 motionManager = CMMotionManager()
    
    internal var previewLayer = AVCaptureVideoPreviewLayer(),
                faceRecognitionAreaView = UIView()
    
    internal var notDetectFace = true
    internal var isLeftEyeReal = false,
                 isRightEyeReal = false
    
    internal var willCheckRealFace = false
    internal var currentMeasurementStopState = true
    internal var currentCheckRealFaceState = false
    internal var pendingMeasurementStopState: Bool?
    internal var pendingMeasurementStopFrameCount = 0
    internal var stableFramesForStopTrue = 2
    internal var stableFramesForStopFalse = 1
    
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
    
    internal var changeBrightness: Bool = false
    
    internal var stableRatio: Double = 0.05
    internal var faceAngle: Int = 5
    internal var baselineAngle: Int = 10
    internal var stableFrameCount: Int = 3
    
    internal var previousFaceFrame: CGRect?
    internal var previousHeadAngle: HeaderAngles?
    internal var baselineHeadAngle: HeaderAngles?
    internal var positionStableCount: Int = 0
    internal var angleStableCount: Int = 0
    
    public override init() {
        super.init()
        print("[++\(#fileID):\(#line)]- init ")
        setIdleTimerDisabled(true) //측정중 화면 자동잠금을 막기 위해 설정
    }
    
    deinit {
        timerReset()
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        cameraSessionManager.clearVideoOutputDelegate(.face, self)
        print("[++\(#fileID)] deinit ")
        setIdleTimerDisabled(false)
    }

    private func setIdleTimerDisabled(_ disabled: Bool) {
        let apply = {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
    
    internal var cropView = UIImageView().then { imv in
        imv.contentMode = .scaleAspectFit
    }
    internal var landMarkView = UIImageView().then { imv in
        imv.contentMode = .scaleAspectFit
    }
    
    internal let antiSpoofingValidator = FaceAntiSpoofingValidator()
    internal let sampleBufferCropper   = SampleBufferCropper()
    internal let imageOrientationMapper  = ImageOrientationMapper()
    internal var recogView = UIView()
    internal var faceDetecView = UIView()
    internal var smallView = UIView()

    // MARK: Measurement State
    internal func emitMeasurementState(
        stop: Bool,
        checkRealFace: Bool,
        requiredStableFrames: Int? = nil
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.emitMeasurementState(
                    stop: stop,
                    checkRealFace: checkRealFace,
                    requiredStableFrames: requiredStableFrames
                )
            }
            return
        }

        let defaultFrames = stop ? stableFramesForStopTrue : stableFramesForStopFalse
        let minimumFrames = max(1, requiredStableFrames ?? defaultFrames)

        if stop == currentMeasurementStopState {
            pendingMeasurementStopState = nil
            pendingMeasurementStopFrameCount = 0

            if checkRealFace != currentCheckRealFaceState {
                currentCheckRealFaceState = checkRealFace
                measurementState.checkRealFace.onNext(checkRealFace)
            }
            return
        }

        if pendingMeasurementStopState != stop {
            pendingMeasurementStopState = stop
            pendingMeasurementStopFrameCount = 1
            return
        }

        pendingMeasurementStopFrameCount += 1
        guard pendingMeasurementStopFrameCount >= minimumFrames else { return }

        pendingMeasurementStopState = nil
        pendingMeasurementStopFrameCount = 0
        currentMeasurementStopState = stop
        currentCheckRealFaceState = checkRealFace
        measurementState.measurementStop.onNext(stop)
        measurementState.checkRealFace.onNext(checkRealFace)
    }

    // MARK: 측정완료
    internal func saveMeasurementOutputs() {
        emitMeasurementState(stop: false, checkRealFace: true, requiredStableFrames: 1)
        
        let measurementComplete      = measurementState.measurementComplete,
            rgbFilePath              = measurementState.rgbFilePath,
            measurementCount         = measurementState.measurementCount

        initRGBData()
        preparingSec    = model.prepareTime
        
        dispatchTimer = DispatchSource.makeTimerSource()
        dispatchTimer?.schedule(deadline: .now(), repeating: 0.01)
        dispatchTimer?.setEventHandler { [weak self] in
            guard let self = self, self.isLeftEyeReal && self.isRightEyeReal else {
                self?.antiSpoofingValidator.initialize()
                self?.lastValue = nil
                self?.isTimerRunning = false
                self?.dispatchTimer?.cancel()
                return
            }
            self.isTimerRunning = true
            measurementCount.onNext(sigR.count)
            if self.sigR.count == model.measurementDataCount {
                if let rgbPath = self.measurementFileWriter.make(
                    data: .rgb,
                    dataSet: totalData
                ) {
//                    guard let dataBin = self.measurementFileWriter.makeBin(
//                        dataSet: totalData,
//                        bytesArr: bytesArray
//                    ) else {
//                        print("byte to bin error")
//                        return
//                    }
                    measurementComplete.onNext(true)
                    rgbFilePath.onNext(rgbPath)
                } else {
                    measurementComplete.onNext(false)
                    rgbFilePath.onNext(URL(fileURLWithPath: ""))
                }
                self.dispatchTimer?.cancel()
                self.isTimerRunning = false
                self.motionManager.stopAccelerometerUpdates()
                self.motionManager.stopGyroUpdates()
            }
        }
        dispatchTimer?.resume()
    }
}
