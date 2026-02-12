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
        case rawData(result: Bool, dataSet: ([Double], [Float], [Float], [Float]))
        case all(result: Bool, path: URL, dataSet: ([Double], [Float], [Float], [Float]))
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
        let x: Double
        let y: Double
        let z: Double
    }
    
    public struct Gyroscope: Equatable {
        let ts: Double
        let x: Double
        let y: Double
        let z: Double
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
    
    private let bag = DisposeBag()
    
    private let document = Document(),
                measurementModel = MeasurementModel()
    
    private let model       = Model.shared,
                cameraSetup = CameraSetup.shared
    
    private var lastFrame: CMSampleBuffer?,
                gCIContext: CIContext?,
                cropFaceRect: CGRect?,
                cropChestRect: CGRect?
    
// MARK: Property 
    private var preparingSec = Int(), // 얼굴을 인식하고 준비하는 시간
                prepareTimer = Timer(),
                measurementTime = Double(), // 측정하는 시간
                measurementTimer = Timer(),
                motionManager = CMMotionManager()
    
    private var previewLayer = AVCaptureVideoPreviewLayer(),
                faceRecognitionAreaView = UIView()
    
    private var notDetectFace = true,
                isLeftEyeReal = false,
                isRightEyeReal = false
    
    private var willCheckRealFace = false
    
    private var lastValue: Int? = nil
    private var lastImage: UIImage?
    private var cropFaceImage: UIImage?
    private var dispatchTimer: DispatchSourceTimer?
    private var isTimerRunning = false
    private var useFaceRecognitionArea = false
    
    private var timeStamp: [Double] = []
    private var sigR: [Float] = []
    private var sigB: [Float] = []
    private var sigG: [Float] = []
    private var tempG: [Float] = []
    private var totalData: [(Double, Float, Float, Float)] = []
    
    private var acc: [Acceleration] = []
    private var gyro: [Gyroscope] = []
    
    private var bytesArray: [[UInt8]] = []
    
    private var frameDataArr: [FrameData] = []
    
    public func collectDataCount(
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
    
    public func captureDeviceMode(
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
    
    public func acceleration(
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
    public func gyroscope(
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
    
    public func pitchYawRoll(
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
    
    public func yMean(
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
    
    public func checkRealFace(
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
    
    public func captureImage(
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
    
    public func stopMeasurement(
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
    
    public func finishedMeasurement(
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
        .drive(onNext: {[weak self] (res, path) in
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
                    output = .rawData(result: res, dataSet: (ts, r, g, b))
                case .all:
                    output = .all(result: res, path: path, dataSet: (ts, r, g, b))
            }
            isSuccess(output)
        })
        .disposed(by: bag)
    }
    
    public func measurementCompleteRatio(
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
    
    public func timesLeft(
        _ com: @escaping((Int) -> ())
    ) {
        let secondRemaining = measurementModel.secondRemaining
        secondRemaining
            .asDriver(onErrorJustReturn: 0)
            .drive(onNext: { remaining in
                com(remaining)
            })
            .disposed(by: bag)
    }
    
    public override init() {
        super.init()
        print("[++\(#fileID):\(#line)]- init ")
        UIApplication.shared.isIdleTimerDisabled = true //측정중 화면 자동잠금을 막기 위해 설정
    }
    
    deinit {
        print("[++\(#fileID)] deinit ")
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private var cropView = UIImageView().then { imv in
        imv.contentMode = .scaleAspectFit
    }
    private var landMarkView = UIImageView().then { imv in
        imv.contentMode = .scaleAspectFit
    }
    
    private let antiSpoofing = Antispoofing()
    private let cropBuffer   = CropBuffer()
    private let orientation  = Orientation()
    private var recogView = UIView()
    private var faceDetecView = UIView()
    private var smallView = UIView()

    open func startSession() {
        self.measurementTime = model.faceMeasurementTime
        self.preparingSec    = model.prepareTime
        self.isTimerRunning  = false
        self.dispatchTimer?.cancel()
        self.measurementTimer.invalidate()
        self.prepareTimer.invalidate()
        
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
    
    open func stopSession() {
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
    // MARK: 측정완료
    private func collectDatas() {
        measurementModel.measurementStop.onNext(false)
        
        let secondRemaining          = measurementModel.secondRemaining,
            measurementCompleteRatio = measurementModel.measurementCompleteRatio,
            measurementComplete      = measurementModel.measurementComplete,
            rgbFilePath              = measurementModel.rgbFilePath,
            frameFilePath            = measurementModel.csvFilePath,
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
            
            if let ratio = self.completionRate(
                second: self.measurementTime
            ) {
                measurementCompleteRatio.onNext("\(ratio)%")
            }
            if 0.55 <= self.measurementTime && self.measurementTime <= 0.59 {
                self.screenCapture()
            }
            secondRemaining.onNext(Int(self.measurementTime))
            measurementCount.onNext(sigR.count)
            self.measurementTime -= 0.01
            if self.measurementTime <= 0.0 {
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
            }
        }
        dispatchTimer?.resume()
    }
    
    func completionRate(
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
// MARK: ACC, GYRO
extension FaceKit {
    public enum MotionDataType {
        case accelerometer
        case gyroscope
    }
    
    public func startAccelerometer() {
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
    
    public func startGryoscope() {
        motionManager.gyroUpdateInterval = 1 / 50
        guard OperationQueue.current != nil else {
            print("acc operation queue return")
            return
        }
        motionManager.startGyroUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self else { return }
            self.collectMotionData(data?.rotationRate, type: .accelerometer, error: error)
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
                measurementModel.acc.accept(accData)
            case .gyroscope:
                let gyroData = Gyroscope.init(ts: ts, x: x, y: y, z: z)
                gyro.append(gyroData)
                measurementModel.gyro.accept(gyroData)
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

// MARK: 카메라 이미지에서 데이터 수집을 위한 delegate
@available(iOS 13.0, *)
extension FaceKit: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let cvimgRef: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("cvimg ref")
            return
        }
        
        CVPixelBufferLockBaseAddress(
            cvimgRef,
            CVPixelBufferLockFlags(rawValue: 0)
        )
        
        self.lastFrame = sampleBuffer
    
        let orientation = orientation.image(fromDevicePosition: .front)
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = orientation
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(cvimgRef))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(cvimgRef))
        
        detectFacesOnDevice(
            in: visionImage,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        ) // 얼굴인식을 위한 함수
        
        CVPixelBufferUnlockBaseAddress(
            cvimgRef,
            CVPixelBufferLockFlags(rawValue: 0)
        )
    }
    
    private func detectFacesOnDevice(
        in image: VisionImage,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        
        var faces: [Face]
        
        let options = FaceDetectorOptions()
        options.landmarkMode = .none
        options.contourMode = .all
        options.classificationMode = .all
        options.performanceMode = .fast
        
        let faceDetector = FaceDetector.faceDetector(options: options)
        
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            print("Failed to detect faces with error: \(error.localizedDescription).")
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            self.updatePreviewOverlayViewWithLastFrame()
            
            if !faces.isEmpty {
                for face in faces {
                    guard face.contours.count != 0 else {
                        print("[++\(#fileID):\(#line)]- face have not contours")
                        return
                    }
                    let previewBounds = self.model.previewLayerBounds
                    let x = face.frame.origin.x,
                        y = face.frame.origin.y,
                        w = face.frame.size.width,
                        h = face.frame.size.height
                    let normalizedRect = CGRect(x: x / imageWidth,
                                                y: y / imageHeight,
                                                width: w / imageWidth,
                                                height: h / imageHeight)
                    
                    let standardizedRect = self.previewLayer.layerRectConverted(
                        fromMetadataOutputRect: normalizedRect
                    ).standardized,
                        recognitionStandardizedRect = CGRect(
                            x: standardizedRect.origin.x + previewBounds.origin.x,
                            y: standardizedRect.origin.y + previewBounds.origin.y,
                            width: standardizedRect.width,
                            height: standardizedRect.height
                        )
                    
                    self.recognitionArea(
                        face: face,
                        imageWidth: imageWidth,
                        imageHeight: imageHeight,
                        recognitionStandardizedRect: recognitionStandardizedRect,
                        faceRecognitionAreaView: faceRecognitionAreaView
                    )
                }
            } else {
                print("On-Device face detector returned no results.")
                self.lastFrame = nil
                self.cropFaceRect = nil
                
                self.initRGBData()
                self.timerReset()
                self.antiSpoofing.initialize()
                
                self.measurementModel.checkRealFace.onNext(false)
                self.measurementModel.measurementStop.onNext(true)
            }
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        DispatchQueue.main.sync { [weak self] in
            guard let self, lastFrame != nil else {
                print("sample buffer error")
                return
            }
            // MARK: Metadata
            if cropFaceRect != nil && isLeftEyeReal && isRightEyeReal {
                if tempG.count >= 30 {
                    measurementModel.checkRealFace.onNext(true)
                    tempG.removeAll()
                    isTimerRunning = true
                    prepareTimer = Timer.scheduledTimer(
                        withTimeInterval: 1,
                        repeats: true
                    ) {[weak self] prepareTimer in
                        guard let self else { return }
                        measurementModel.secondRemaining.onNext(preparingSec)
                        if preparingSec == 0 {
                            screenCapture()
                            prepareTimer.invalidate()
                            cameraSetup.setUpCaptureDevice(.locked)
                            collectDatas()
                        }
                        preparingSec -= 1
                    }
                }
            } else {
                cameraSetup.setUpCaptureDevice(.autoExpose)
                measurementModel.checkRealFace.onNext(false)
                initRGBData()
                isTimerRunning = false
                dispatchTimer?.cancel()
                measurementTimer.invalidate()
                prepareTimer.invalidate()
            }
        }
    }
    
    private func recognitionArea(
        face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        recognitionStandardizedRect: CGRect, // 인식된 얼굴 frame
        faceRecognitionAreaView: UIView
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let recognitionArea = useFaceRecognitionArea
            ? faceRecognitionAreaView.frame
            : UIScreen.main.bounds
            
            let isMeasurableFacePosition = self.faceDetectAreaCondition(
                faceFrame: recognitionStandardizedRect,
                useFaceRecognitionArea: useFaceRecognitionArea,
                recognitionArea: recognitionArea
            )

            if isMeasurableFacePosition {
                self.measurementModel.measurementStop.onNext(false)
                self.cropFaceRect = CGRect(
                    x: face.frame.origin.x,
                    y: face.frame.origin.y,
                    width: face.frame.width,
                    height: face.frame.height
                ).integral // 얼굴인식 위치 계산
                
                self.addContours(
                    for: face,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight
                )
            } else {
                self.lastFrame = nil
                self.cropFaceRect = nil
                
                self.preparingSec    = self.model.prepareTime
                self.measurementTime = self.model.faceMeasurementTime
                
                self.initRGBData()
                self.timerReset()
                self.antiSpoofing.initialize()
                self.measurementModel.measurementStop.onNext(true)
            }
        }
    }
    
    private func faceDetectAreaCondition(
        faceFrame: CGRect,
        useFaceRecognitionArea: Bool,
        recognitionArea: CGRect
    ) -> Bool {
        let minX = recognitionArea.minX + recognitionArea.width * 0.07
        let maxX = recognitionArea.maxX - recognitionArea.width * 0.07
        let minY = recognitionArea.minY + recognitionArea.height * 0.07
        let maxY = recognitionArea.maxY - recognitionArea.height * 0.07
        
        let smallMinX = recognitionArea.minX + (recognitionArea.width / 2.2)
        let smallMaxX = recognitionArea.maxX - (recognitionArea.width / 2.2)
        let smallMinY = recognitionArea.minY + (recognitionArea.height / 2.2)
        let smallMaxY = recognitionArea.maxY - (recognitionArea.height / 2.2)
        
        let faceMinX = faceFrame.minX + faceFrame.width * 0.25
        let faceMaxX = faceFrame.maxX - faceFrame.width * 0.25
        let faceMinY = faceFrame.minY + faceFrame.height * 0.2
        let faceMaxY = faceFrame.maxY - faceFrame.height * 0.2
        
//        Debug용 View 설정 - 측정구역(대, 소), 감지된 얼굴
//        DispatchQueue.main.async {
//            self.cropView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
//            self.landMarkView.frame = CGRect(x: 180, y: 0, width: 120, height: 120)
//
//            self.recogView.layer.borderColor = UIColor.red.cgColor
//            self.recogView.layer.borderWidth = 1
//
//            self.faceDetecView.layer.borderColor = UIColor.blue.cgColor
//            self.faceDetecView.layer.borderWidth = 1
//
//            self.smallView.layer.borderColor = UIColor.green.cgColor
//            self.smallView.layer.borderWidth = 1
//
//            self.recogView.frame = recognitionArea
//            self.faceDetecView.frame = CGRect(
//                x: faceMinX,
//                y: faceMinY,
//                width: faceMaxX - faceMinX,
//                height: faceMaxY - faceMinY
//            )
//            self.smallView.frame = CGRect(
//                x: smallMinX,
//                y: smallMinY,
//                width: smallMaxX - smallMinX,
//                height: smallMaxY - smallMinY
//            )
//        }

        let useRecognitionArea = (minX <= faceMinX && faceMinX <= smallMinX)
        && (smallMaxX <= faceMaxX && faceMaxX <= maxX)
        && (faceMinY <= smallMaxY && smallMinY <= faceMaxY)
        let unUseRecognitionArea = (minX <= faceMinX && faceMinX <= maxX)
        && (minY <= faceMinY && faceMinY <= maxY)
        let areaCondition = useFaceRecognitionArea
        ? useRecognitionArea
        : unUseRecognitionArea
        
        return areaCondition
    }
    
    private func initRGBData() {
        timeStamp.removeAll()
        sigR.removeAll()
        sigB.removeAll()
        sigG.removeAll()
        tempG.removeAll()
        totalData.removeAll()
        bytesArray.removeAll()
        
        frameDataArr.removeAll()
    }
    
    private func timerReset() {
        isTimerRunning = false
        dispatchTimer?.cancel()
        measurementTimer.invalidate()
        prepareTimer.invalidate()
    }
    
    private func modeState(mode: Int) -> String {
        return mode == 0
        ? "LOCKED"
        : mode == 1
        ? "AUTO"
        : "CONTINUOUS"
    }
}

// MARK: 랜드마크 제거
extension FaceKit {
    private func addContours(
        for face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        if let rect  = cropFaceRect,
           let frame = lastFrame,
           let faceContour = face.contour(ofType: .face),
           let leftEyeContour = face.contour(ofType: .leftEye),
           let leftEyeBrowTopContour = face.contour(ofType: .leftEyebrowTop),
           let leftEyeBrowBottomContour = face.contour(ofType: .leftEyebrowBottom),
           let rightEyeContour = face.contour(ofType: .rightEye),
           let rightEyeBrowTopContour = face.contour(ofType: .rightEyebrowTop),
           let rightEyeBrowBottomContour = face.contour(ofType: .rightEyebrowBottom),
           let upperLipContour = face.contour(ofType: .upperLipTop),
           let lowerLipContour = face.contour(ofType: .lowerLipBottom) {
            
            var facePath = UIBezierPath().then { p in
                p.lineWidth = 1
            }
            var leftEyePath = UIBezierPath().then { p in
                p.lineWidth = 1
            }
            var rightEyePath = UIBezierPath().then { p in
                p.lineWidth = 1
            }
            var leftEyeBrowPath = UIBezierPath().then { p in
                p.lineWidth = 1
            }
            var rightEyeBrowPath = UIBezierPath().then { p in
                p.lineWidth = 1
            }
            var lipsPath = UIBezierPath().then { p in
                p.lineWidth = 1
            }

            if willCheckRealFace {
                if !isTimerRunning {
                    let (left, right) = antiSpoofing.checkReal(face)
                    isLeftEyeReal  = left
                    isRightEyeReal = right
                }
            } else {
                isLeftEyeReal  = true
                isRightEyeReal = true
            }
            
            guard let faceCropBuffer = cropBuffer.sample(frame, with: rect) else {
                print("[++\(#fileID):\(#line)]- crop face error")
                return
            }
            
            draw(
                previewLayer: previewLayer,
                facePoints: faceContour.points,
                leftEyePoints: leftEyeContour.points,
                rightEyePoints: rightEyeContour.points,
                leftEyeBrowPoints: leftEyeBrowTopContour.points + leftEyeBrowBottomContour.points ,
                rightEyeBrowPoints: rightEyeBrowTopContour.points + rightEyeBrowBottomContour.points,
                lipsPoints: upperLipContour.points + lowerLipContour.points,
                cropImage: SampleBufferConverter.convertingBufferFront(faceCropBuffer),
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
            
            func draw(
                previewLayer: AVCaptureVideoPreviewLayer?,
                facePoints: [VisionPoint],
                leftEyePoints: [VisionPoint],
                rightEyePoints: [VisionPoint],
                leftEyeBrowPoints: [VisionPoint],
                rightEyeBrowPoints: [VisionPoint],
                lipsPoints: [VisionPoint],
                cropImage: UIImage?,
                imageWidth: CGFloat,
                imageHeight: CGFloat
            ) {
                
                facePath.lineJoinStyle = .miter
                
                guard let previewLayer = previewLayer,
                      let cropImage = cropImage else {
                    print("crop image return")
                    return
                }
                
                gridPath(
                    previewLayer: previewLayer,
                    width: imageWidth,
                    height: imageHeight,
                    points: facePoints,
                    path: &facePath
                )
                
                gridPath(
                    previewLayer: previewLayer,
                    width: imageWidth,
                    height: imageHeight,
                    points: leftEyePoints,
                    path: &leftEyePath
                )
                gridPath(
                    previewLayer: previewLayer,
                    width: imageWidth,
                    height: imageHeight,
                    points: rightEyePoints,
                    path: &rightEyePath
                )
                
                gridPath(
                    previewLayer: previewLayer,
                    width: imageWidth,
                    height: imageHeight,
                    points: leftEyeBrowPoints,
                    path: &leftEyeBrowPath
                )
                gridPath(
                    previewLayer: previewLayer,
                    width: imageWidth,
                    height: imageHeight,
                    points: rightEyeBrowPoints,
                    path: &rightEyeBrowPath
                )
                
                gridPath(
                    previewLayer: previewLayer,
                    width: imageWidth,
                    height: imageHeight,
                    points: lipsPoints,
                    path: &lipsPath
                )
                
                facePath.append(leftEyePath)
                facePath.append(rightEyePath)
                facePath.append(leftEyeBrowPath)
                facePath.append(rightEyeBrowPath)
                facePath.append(lipsPath)
                cropFaceImage = cropImage
                
                guard let cropLandMarkFace = getMaskedImage(
                    picture: cropImage,
                    cgPath: facePath.cgPath
                ),
                      let sampleBuffer = cropLandMarkFace.createCMSampleBuffer() else { fatalError("face crop image return") }
//                self.cropView.image = cropImage
//                landMarkView.image = cropLandMarkFace
           
                extractRGBFromDetectFace(sampleBuffer: sampleBuffer)
                collectionByteData(sampleBuffer: sampleBuffer)
                extractYUVFromDetectFace(
                    sampleBuffer: sampleBuffer,
                    face: face,
                    cropLandMarkFace: cropLandMarkFace
                )
            }
        } else {
            print("[++\(#fileID):\(#line)]- face is nil")
        }
    }
    
    private func gridPath(
        previewLayer: AVCaptureVideoPreviewLayer,
        width: CGFloat,
        height: CGFloat,
        points: [VisionPoint],
        path: inout UIBezierPath
    ) {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        for (i, point) in points.enumerated() {
            let cgPoint = normalizedPoint(
                previewLayer: previewLayer,
                fromVisionPoint: point,
                width: width,
                height: height
            )
            if i == 0 {
                path.move(to: CGPoint(x: cgPoint.x, y: cgPoint.y))
            } else if i == points.count - 1 {
                path.addLine(to: CGPoint(x: cgPoint.x, y: cgPoint.y))
                path.close()
                path.stroke()
            } else {
                path.addLine(to: CGPoint(x: cgPoint.x, y: cgPoint.y))
            }
        }
        UIGraphicsEndImageContext()
    }
    
    private func normalizedPoint(
        previewLayer: AVCaptureVideoPreviewLayer,
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
    ) -> CGPoint {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
    }
    
    private func getMaskedImage(
        picture: UIImage,
        cgPath: CGPath
    ) -> UIImage? {
        let flipped     = orientation.flipImage(picture) ?? picture
        let flippedPath = orientation.flipPathHorizontally(cgPath, in: picture.size)
        
        let rect = CGRect(origin: .zero, size: flipped.size)
        let maskPath = (flippedPath.resized(to: rect) ?? flippedPath)
        
//        UIGraphicsBeginImageContextWithOptions(picture.size, false, 1.0)
        UIGraphicsBeginImageContextWithOptions(picture.size, false, 0.8)
        defer { UIGraphicsEndImageContext() }
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        
        ctx.addPath(maskPath)
        ctx.clip(using: .evenOdd)
        
        // ✅ 핵심: UIImage.draw는 orientation(회전/미러)을 반영해서 그려줌
        flipped.draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// MARK: RGB / ByteArray / YUA -> Ymean / Capture Image
extension FaceKit {
    private func extractRGBFromDetectFace(
        sampleBuffer: CMSampleBuffer
    ) {
        guard let faceRGB = SampleBufferConverter.detectFaceSampleBuffer(sampleBuffer) else {
            print("casting error")
            return
        }
        guard let r = faceRGB[0] as? Float,
              let g = faceRGB[1] as? Float,
              let b = faceRGB[2] as? Float else {
            print("rgb casting error")
            return
        }
        
        let ts = (Date().timeIntervalSince1970 * 1000000).rounded()
        if isTimerRunning {
            guard ts > 100 else { return }
            let dataSet:(Double, Float, Float, Float) = (ts, r, g, b)
            timeStamp.append(ts)
            sigR.append(r)
            sigG.append(g)
            sigB.append(b)
            totalData.append(dataSet)
        } else if !isTimerRunning {
            tempG.append(g)
        }
    }
    
    private func collectionByteData(
        sampleBuffer: CMSampleBuffer
    ) {
        guard let byteData = SampleBufferConverter.dataSampleBuffer36x36(sampleBuffer) else {
            return print("objc chest casting error")
        }
        bytesArray.append(Array(byteData))
    }
    
    private func extractYUVFromDetectFace(
        sampleBuffer: CMSampleBuffer,
        face: Face,
        cropLandMarkFace: UIImage
    ) {
        let yMean = SampleBufferConverter.extractYUVFromDetectFace(sampleBuffer)
        //degree
        let pitch = face.headEulerAngleX  // 위/아래
        let yaw   = face.headEulerAngleY  // 좌/우 회전
        let roll  = face.headEulerAngleZ  // 좌/우 기울기(tilt)
        let device = cameraSetup.useCaptureDevice()
        let iso = device.iso
        //AE locked = 0, autoExpose = 1, continuousAutoExposure = 2
        let exposureMode = device.exposureMode.rawValue
        let expousreState = modeState(mode: exposureMode)
        //AF locked = 0, autoFocus = 1, continuousAutoFocus = 2
        let focusMode = device.focusMode.rawValue
        let focusState = modeState(mode: focusMode)
        //AWB locked = 0, autoWhiteBalance = 1, continuousAutoWhiteBalance = 2
        let whiteBalanceMode = device.whiteBalanceMode.rawValue
        let wbState = modeState(mode: whiteBalanceMode)
        let ts = (Date().timeIntervalSince1970 * 1000000).rounded()
        
        frameDataArr.append(
            .init(
                timestampUS: ts,
                width: Int(cropLandMarkFace.size.width),
                height: Int(cropLandMarkFace.size.height),
                brightness: yMean,
                faceYaw: yaw,
                facePitch: pitch,
                faceRoll: roll,
                iso: iso,
                aeState: expousreState,
                awbState: wbState,
                afState: focusState
            )
        )
        
//        yuvY.append(yMean)
//        pitchArr.append(pitch)
//        yawArr.append(yaw)
//        rollArr.append(roll)
//        imgWidth.append(Int(cropLandMarkFace.size.width))
//        imgHeight.append(Int(cropLandMarkFace.size.height))
//        aeArr.append(expousreState)
//        afArr.append(focusState)
//        awbArr.append(wbState)
        
        measurementModel.headAnglesRelay.accept(
            HeaderAngles.init(
                pitch: pitch,
                yaw: yaw,
                roll: roll
            )
        )
        measurementModel.metaData.accept(
            .init(
                iso: iso,
                exposureMode: expousreState,
                focusMode: focusState,
                whiteBalanceMode: wbState,
            )
        )
        measurementModel.yMean.onNext(yMean)
    }
  
    private func screenCapture() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let frame = lastFrame,
               let captureImage = SampleBufferConverter.convertingBufferFront(frame) {
                measurementModel.captureImage.onNext((screen: captureImage, crop: cropFaceImage))
            }
        }
    }
}

extension FaceKit {
    public func collectData() {
       
    }
}
