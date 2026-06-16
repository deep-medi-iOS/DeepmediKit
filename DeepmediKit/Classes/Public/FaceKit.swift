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
    public private(set) var tfliteReady = false
    public private(set) var tfliteInitMessage = "not initialized"
    public private(set) var latestCoreMetrics: PhysMorphNetResult?

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
    
    public struct PhysMorphNet: Equatable {
        public let metrics: PhysMorphNetResult
        public let ts: [Double]
        public let binPath: URL?
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
    internal var tfliteRunner: TFLiteModelRunner?
    
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
    internal var frameTimestampUS: [UInt64] = []
    internal var frames = [SampleBufferConverter.FaceBinFrame]()
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
        initializeTFLiteModel()
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

    private func initializeTFLiteModel() {
        do {
            let runner = try TFLiteModelRunner(modelName: "model_core", threadCount: 2)
            let inputBytes = try runner.inputTensorByteCount()
            tfliteRunner = runner
            tfliteReady = true
            tfliteInitMessage = "loaded model_core.tflite (inputBytes=\(inputBytes))"
            print("[++\(#fileID):\(#line)]- TFLite init success: \(tfliteInitMessage)")
        } catch {
            tfliteRunner = nil
            tfliteReady = false
            tfliteInitMessage = "failed to load model_core.tflite: \(error.localizedDescription)"
            print("[++\(#fileID):\(#line)]- TFLite init failed: \(tfliteInitMessage)")
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
            measurementCount         = measurementState.measurementCount

        initRGBData()
        preparingSec = model.prepareTime
        
        dispatchTimer = DispatchSource.makeTimerSource()
        dispatchTimer?.schedule(deadline: .now(), repeating: 0.01)
        dispatchTimer?.setEventHandler(
            qos: .default,
            flags: [],
            handler:  { [weak self] in
                guard let self = self,
                      self.isLeftEyeReal && self.isRightEyeReal else {
                    self?.antiSpoofingValidator.initialize()
                    self?.lastValue = nil
                    self?.isTimerRunning = false
                    self?.dispatchTimer?.cancel()
                    return
                }
                self.isTimerRunning = true
                measurementCount.onNext(sigR.count)
                if self.sigR.count == measurementDataCount {
                    if let faceBin = self.measurementFileWriter.makeFaceBin(
                        frames: bytesArray,
                        timestampsUS: frameTimestampUS
                    ) {
                        measurementComplete.onNext(true)
                        guard let coreResult = self.runCoreFromFaceBin(faceBin) else {
                            print("[++\(#fileID):\(#line)]- face bin error ")
                            return
                        }
                        self.publishCoreMetrics(coreResult, faceBin)
                    } else {
                        measurementComplete.onNext(false)
                        self.publishCoreMetrics(
                            .init(
                                sdnn: 0.0,
                                rmssd: 0.0,
                                hr: 0.0,
                                quality: 0.0,
                                rrList: [],
                                ppg: []
                            ),
                        URL(fileURLWithPath: "")
                        )
                    }
                    self.dispatchTimer?.cancel()
                    self.isTimerRunning = false
                    self.motionManager.stopAccelerometerUpdates()
                    self.motionManager.stopGyroUpdates()
                }
            }
        )
        dispatchTimer?.resume()
    }

    private func runCoreFromFrames(
        _ frames: [SampleBufferConverter.FaceBinFrame]
    ) -> PhysMorphNetResult? {
        do {
            if tfliteRunner == nil {
                tfliteRunner = try TFLiteModelRunner(modelName: "model_core", threadCount: 2)
            }
            guard let runner = tfliteRunner else {
                print("[++\(#fileID):\(#line)]- TFLite runner is nil")
                return nil
            }
            return try FaceCoreMetricsCalculator.analyze(frames: frames, runner: runner)
        } catch {
            print("[++\(#fileID):\(#line)]- core inference failed: \(error.localizedDescription)")
            return nil
        }
    }

    internal func publishCoreMetrics(
        _ metrics: PhysMorphNetResult,
        _ path: URL
    ) {
        latestCoreMetrics = metrics
        measurementState.coreMetrics.accept(metrics)
        measurementState.binFilePath.onNext(path)
    }

    internal func runCoreFromFaceBin(
        _ fileURL: URL
    ) -> PhysMorphNetResult? {
        do {
            let parsedFrames = try loadFaceBinFrames(from: fileURL)
            return runCoreFromFrames(parsedFrames)
        } catch {
            print("[++\(#fileID):\(#line)]- face.bin parse failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadFaceBinFrames(
        from fileURL: URL
    ) throws -> [SampleBufferConverter.FaceBinFrame] {
        let data = try Data(contentsOf: fileURL)
        var offset = 0

        let width = try readBEUInt64(from: data, offset: &offset)
        let height = try readBEUInt64(from: data, offset: &offset)
        let frameCount = Int(try readBEUInt64(from: data, offset: &offset))

        guard width == 36, height == 36 else {
            throw NSError(
                domain: "FaceKit",
                code: -2001,
                userInfo: [NSLocalizedDescriptionKey: "Invalid face.bin size: \(width)x\(height)"]
            )
        }

        let frameByteCount = 36 * 36 * 3
        let totalFrameBytes = frameCount * frameByteCount
        guard offset + totalFrameBytes <= data.count else {
            throw NSError(
                domain: "FaceKit",
                code: -2002,
                userInfo: [NSLocalizedDescriptionKey: "face.bin frame payload is truncated"]
            )
        }

        let framePayload = data.subdata(in: offset..<(offset + totalFrameBytes))
        offset += totalFrameBytes

        var timestamps = [UInt64]()
        timestamps.reserveCapacity(frameCount)
        for _ in 0..<frameCount {
            timestamps.append(try readBEUInt64(from: data, offset: &offset))
        }

        var frames = [SampleBufferConverter.FaceBinFrame]()
        frames.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            let start = index * frameByteCount
            let end = start + frameByteCount
            let rgb = Array(framePayload[start..<end])
            let timestamp = timestamps[index]
            frames.append(.init(rgb36x36: rgb, timestampUS: timestamp))
        }
        return frames
    }

    private func readBEUInt64(
        from data: Data,
        offset: inout Int
    ) throws -> UInt64 {
        let nextOffset = offset + 8
        guard nextOffset <= data.count else {
            throw NSError(
                domain: "FaceKit",
                code: -2003,
                userInfo: [NSLocalizedDescriptionKey: "face.bin header is truncated"]
            )
        }

        let value = data[offset..<nextOffset].reduce(UInt64(0)) { partial, byte in
            (partial << 8) | UInt64(byte)
        }
        offset = nextOffset
        return value
    }
}
