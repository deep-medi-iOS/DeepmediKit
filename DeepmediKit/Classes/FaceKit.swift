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
import RxSwift
import RxCocoa
import CoreMotion
import Then

public class FaceKit: NSObject {
    public enum HealthCareInfo {
        
        public enum genderType: Int {
            case MALE = 0, FEMALE = 1
        }
        
        public enum exerciseType: Int {
            case OFTEN = 0, SOMETIMES = 1
        }
        
        public enum smokeType: Int {
            case NONE = 0, PAST = 1, NOW = 2
        }
        
        public enum diabetesType: Int {
            case NONE = 0, EXISTENCE = 1
        }
    }
    
    private let bag = DisposeBag()
    
    private let makeDocument = Document(),
                measurementModel = MeasurementModel()
    
    private let service = Service.manager
    
    private let dataModel = DataModel.shared,
                model = Model.shared,
                recordModel = RecordModel.shared,
                cameraSetup = CameraSetup.shared
    
    private var lastFrame: CMSampleBuffer?,
                gCIContext: CIContext?,
                cropFaceRect: CGRect?,
                cropChestRect: CGRect?
    
    // MARK: Property
    private var preparingSec = Int(), // 얼굴을 인식하고 준비하는 시간
                measurementTime = Double(), // 측정하는 시간
                measurementTimer = Timer()
    
    private var previewLayer = AVCaptureVideoPreviewLayer(),
                faceRecognitionAreaView = UIView()
    
    private var notDetectFace = true,
                isReal = false ,
                diffArr:[CGFloat] = [],
                checkArr:[Bool] = []
    
    public func checkRealFace(
        _ isReal: @escaping((Bool) -> ())
    ) {
        let check = self.measurementModel.checkRealFace
        check
            .asDriver(onErrorJustReturn: false)
            .distinctUntilChanged()
            .drive { check in
                isReal(check)
            }
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
        _ isSuccess: @escaping((Bool, URL?) -> ())
    ) {
        let completion = self.measurementModel.faceMeasurementComplete
        completion
            .asDriver(onErrorJustReturn: (false, URL(string: "")))
            .drive(onNext: { result in
                isSuccess(result.0, result.1)
            })
            .disposed(by: bag)
    }
    
    ///exerciseType(30분이상 신체활동): often = 주 3회 이상, sometimes = 주 2회이상 /
    ///smoke(흡연): none = 비흡엽, past = 과거흡연, now = 현재흡연 /
    ///diabetes(당뇨 여부): none = 아니오, existence = 예 /
    ///return
    ///hr(심박수), mentalStress(정신적스트레스), physicalStress(육제척스트레스), af(불규칙심박): 0 = 규칙적임, 1 = 불규칙적임, sys(수축기), dia(이완기)
    ///cardioRisk(심혈관 위험도)
    public func resultHealthInfo(
        secretKey: String,
        apiKey: String,
        genderType: HealthCareInfo.genderType,
        age: Int,
        height: Int,
        weight: Int,
        belly: Int? = nil,
        exerciseType: HealthCareInfo.exerciseType? = nil,
        smokeType: HealthCareInfo.smokeType? = nil,
        diabetesType: HealthCareInfo.diabetesType? = nil,
        _ healthInfo: @escaping(([String: Any]) -> ())
    ) {
        
        self.model.secretKey = secretKey
        self.model.apiKey = apiKey
        self.model.age = age
        self.model.gender = genderType.rawValue
        self.model.height = height
        self.model.weight = weight
        self.model.belly = belly
        self.model.act = exerciseType?.rawValue
        self.model.smoke = smokeType?.rawValue
        self.model.diabetes = diabetesType?.rawValue
        
        let healthCareInfoResult = self.measurementModel.healthCareInfoResult
        
        healthCareInfoResult
            .asDriver(onErrorJustReturn: ["": 0])
            .drive(onNext: { result in
                healthInfo(result)
            })
            .disposed(by: bag)
    }

    
    public func measurementCompleteRatio(
        _ com: @escaping((String) -> ())
    ) {
        let ratio = self.measurementModel.measurementCompleteRatio
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
        let secondRemaining = self.measurementModel.secondRemaining
        secondRemaining
            .asDriver(onErrorJustReturn: 0)
            .drive(onNext: { remaining in
                com(remaining)
            })
            .disposed(by: bag)
    }
    
    public override init() {
        super.init()
        UIApplication.shared.isIdleTimerDisabled = true //측정중 화면 자동잠금을 막기 위해 설정
        if let openCVstr = OpenCVWrapper.openCVVersionString() {
            print("\(openCVstr)")
        }
    }
    
    deinit {
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    open func startSession() {
        self.measurementTime = self.model.faceMeasurementTime
        self.preparingSec = 1
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
            if let previewLayer = self.model.previewLayer {
                self.previewLayer = previewLayer
            }
            
            if self.model.useFaceRecognitionArea,
               let faceRecognitionAreaView = self.model.faceRecognitionAreaView {
                self.faceRecognitionAreaView = faceRecognitionAreaView
            }
            
            self.cameraSetup.useSession().startRunning()
        }
    }
    
    open func stopSession() {
        self.lastFrame = nil
        self.cropFaceRect = nil
        
        self.measurementTimer.invalidate()
        self.dataModel.initRGBData()
        self.dataModel.gTempData.removeAll()
        self.diffArr.removeAll()
        self.checkArr.removeAll()
        
        self.cameraSetup.useCaptureDevice().exposureMode = .autoExpose
        
        DispatchQueue.global(qos: .background).async {
            self.cameraSetup.useSession().stopRunning()
        }
    }
    
    private func collectDatas() {
        self.measurementModel.measurementStop.onNext(false)
        
        let secondRemaining = self.measurementModel.secondRemaining,
            measurementCompleteRatio = self.measurementModel.measurementCompleteRatio,
            measurementComplete = self.measurementModel.faceMeasurementComplete,
            healthCareInfoResult = measurementModel.healthCareInfoResult
        
        self.dataModel.initRGBData()
        self.dataModel.gTempData.removeAll()
        self.diffArr.removeAll()
        self.checkArr.removeAll()
        
        self.preparingSec = 1
        self.measurementTime = self.model.faceMeasurementTime
        self.measurementTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { timer in
            let ratio = Int(100.0 - self.measurementTime * 100.0 / self.model.faceMeasurementTime)
            measurementCompleteRatio.onNext("\(ratio)%")
            secondRemaining.onNext(Int(self.measurementTime))
            self.measurementTime -= 0.1
            if self.measurementTime <= 0 {
                timer.invalidate()
                self.makeDocument.makeDocument(data: .rgb) //측정한 데이터 파일로 변환
                if let rgbPath = self.dataModel.rgbDataPath { //파일이 존재할때 api호출 시도
                    measurementComplete.onNext((result: true, url: rgbPath))
                    
                    self.service.facePPG(
                        secretKey: self.model.secretKey,
                        apiKey: self.model.apiKey,
                        rgbPath: rgbPath,
                        age: self.model.age,
                        gender: self.model.gender,
                        weight: self.model.weight,
                        height: self.model.height
                    ) { healthInfoErr in
                        if let err = healthInfoErr {
                            healthCareInfoResult.onNext(([ "healthInfo response fail": err ]))
                        } else {
                            if let belly = self.model.belly,
                               let act = self.model.act,
                               let smoke = self.model.smoke,
                               let diabetes = self.model.diabetes {
                                
                                self.service.cardiacRisk(
                                    secretKey: self.model.secretKey,
                                    apiKey: self.model.apiKey,
                                    gender: self.model.gender,
                                    age: self.model.age,
                                    height: self.model.height,
                                    weight: self.model.weight,
                                    belly: belly,
                                    act: act,
                                    smoke: smoke,
                                    diabetes: diabetes,
                                    sys: self.recordModel.sys,
                                    dia: self.recordModel.dia
                                ) { cardioRiskErr in
                                    if let err = cardioRiskErr {
                                        healthCareInfoResult.onNext(([ "cardioRisk fail": err ]))
                                    } else {
                                        healthCareInfoResult.onNext(([
                                            "hr": self.recordModel.hr,
                                            "physicalStress": self.recordModel.physicalStress,
                                            "mentalStress": self.recordModel.mentalStress,
                                            "af": self.recordModel.af,
                                            "sys": self.recordModel.sys,
                                            "dia": self.recordModel.dia,
                                            "cardioRisk": self.recordModel.cardioRisk
                                        ]))
                                    }
                                }
                            } else {
                                print("belly: \(self.model.belly), act: \(self.model.act), smoke: \(self.model.smoke), diabetes: \(self.model.diabetes)")
                                healthCareInfoResult.onNext(([
                                    "hr": self.recordModel.hr,
                                    "physicalStress": self.recordModel.physicalStress,
                                    "mentalStress": self.recordModel.mentalStress,
                                    "af": self.recordModel.af,
                                    "sys": self.recordModel.sys,
                                    "dia": self.recordModel.dia,
                                    "cardioRisk": 9999.0
                                ]))
                            }
                        }
                    }
                } else {
                    measurementComplete.onNext((result: false,url: URL(string: "")))
                }
            }
        }
    }
}

@available(iOS 13.0, *)
extension FaceKit: AVCaptureVideoDataOutputSampleBufferDelegate { // 카메라 이미지에서 데이터 수집을 위한 delegate
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
        
        let orientation = self.imageOrientation(fromDevicePosition: .front)
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = orientation
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(cvimgRef))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(cvimgRef))
        
        self.detectFacesOnDevice(
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
        options.classificationMode = .none
        options.performanceMode = .fast
        
        let faceDetector = FaceDetector.faceDetector(options: options)
        
        do {
            faces = try faceDetector.results(in: image)
        } catch let error {
            print("Failed to detect faces with error: \(error.localizedDescription).")
            return
        }
        
        self.updatePreviewOverlayViewWithLastFrame()
        
        DispatchQueue.main.sync {
            
            if !faces.isEmpty {
                
                for face in faces {
                    
                    let previewBounds = self.model.previewLayerBounds
                    
                    if self.model.useFaceRecognitionArea {
                        
                        let x = (face.frame.origin.x + face.frame.size.width * 0.3),
                            y = (face.frame.origin.y + face.frame.size.height * 0.2),
                            w = (face.frame.size.width * 0.4),
                            h = (face.frame.size.height * 0.6)
                        let normalizedRect = CGRect(x: x / imageWidth,
                                                    y: y / imageHeight,
                                                    width: w / imageWidth,
                                                    height: h / imageHeight)
                        let standardizedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: normalizedRect).standardized,
                            recognitionStandardizedRect = CGRect(x: standardizedRect.origin.x + previewBounds.origin.x,
                                                                 y: standardizedRect.origin.y + previewBounds.origin.y,
                                                                 width: standardizedRect.width,
                                                                 height: standardizedRect.height)
                        
                        self.recognitionArea(
                            face: face,
                            imageWidth: imageWidth,
                            imageHeight: imageHeight,
                            standardizedRect: recognitionStandardizedRect,
                            faceRecognitionAreaView: faceRecognitionAreaView
                        )
                        
                    } else {
                        
                        let x1 = (face.frame.origin.x + face.frame.size.width * 0.1),
                            y1 = (face.frame.origin.y + face.frame.size.height * 0.1),
                            w1 = (face.frame.size.width * 0.8),
                            h1 = (face.frame.size.height * 0.8)// 얼굴인식 위치 설정
                        let noneRecognitionNormalizedRect = CGRect(x: x1 / imageWidth,
                                                                   y: y1 / imageHeight,
                                                                   width: w1 / imageWidth,
                                                                   height: h1 / imageHeight)
                        let standardizedRect1 = self.previewLayer.layerRectConverted(fromMetadataOutputRect: noneRecognitionNormalizedRect).standardized,
                            noneRecgnitionStandardizedRect = CGRect(x: standardizedRect1.origin.x + previewBounds.origin.x,
                                                                    y: standardizedRect1.origin.y + previewBounds.origin.y,
                                                                    width: standardizedRect1.width,
                                                                    height: standardizedRect1.height)
                        
                        self.noneRecognitionArea(
                            face: face,
                            imageWidth: imageWidth,
                            imageHeight: imageHeight,
                            standardizedRect: noneRecgnitionStandardizedRect
                        )
                    }
                }
            } else {
                self.lastFrame = nil
                self.cropFaceRect = nil
                self.dataModel.gTempData.removeAll()
                self.measurementModel.measurementStop.onNext(true)
            }
        }
    }
    
    private func recognitionArea(
        face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        standardizedRect: CGRect,
        faceRecognitionAreaView: UIView
    ) {
        
        if faceRecognitionAreaView.frame.minX <= standardizedRect.minX &&
            faceRecognitionAreaView.frame.maxX >= standardizedRect.maxX &&
            faceRecognitionAreaView.frame.minY <= standardizedRect.minY &&
            faceRecognitionAreaView.frame.maxY >= standardizedRect.maxY {
            
            self.cropFaceRect = CGRect(x: face.frame.origin.x,
                                       y: face.frame.origin.y,
                                       width: face.frame.width,
                                       height: face.frame.height).integral // 얼굴인식 위치 계산
            self.addContours(
                for: face,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
        } else {
            self.lastFrame = nil
            self.cropFaceRect = nil
            self.dataModel.gTempData.removeAll()
            self.dataModel.initRGBData() // 중간에 쌓여있을 수 있는 데이터 초기화
            self.measurementTimer.invalidate()
            self.diffArr.removeAll()
            self.checkArr.removeAll()
            self.measurementModel.measurementStop.onNext(true)
        }
    }
    
    private func noneRecognitionArea(
        face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        standardizedRect: CGRect
    ) {
        
        let minX = UIScreen.main.bounds.minX,
            minY = UIScreen.main.bounds.minY,
            maxX = UIScreen.main.bounds.maxX,
            maxY = UIScreen.main.bounds.maxY
        
        if standardizedRect.minX >= minX
            && standardizedRect.maxX <= maxX
            && standardizedRect.minY >= minY
            && standardizedRect.maxY <= maxY {
            
            self.cropFaceRect = CGRect(x: face.frame.origin.x,
                                       y: face.frame.origin.y,
                                       width: face.frame.width,
                                       height: face.frame.height).integral // 얼굴인식 위치 계산
            self.addContours(
                for: face,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
        } else {
            self.measurementModel.measurementStop.onNext(true)
            self.lastFrame = nil
            self.cropFaceRect = nil
            self.dataModel.gTempData.removeAll()
            self.diffArr.removeAll()
            self.checkArr.removeAll()
        }
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
        DispatchQueue.main.sync {
            guard lastFrame != nil else {
                print("sample buffer error")
                return
            }
            if self.model.useFaceRecognitionArea {
                self.useRecogntionFace()
            } else {
                self.noneUseRecognitionFace()
            }
        }
    }
    
    private func useRecogntionFace() {
        if self.cropFaceRect != nil {
            if self.dataModel.gTempData.count >= self.preparingSec * 30 && self.isReal {
                self.measurementModel.checkRealFace.onNext(true)
                self.cameraSetup.setUpCatureDevice()
                self.collectDatas()
            }
        } else {
            self.measurementModel.checkRealFace.onNext(false)
            self.dataModel.gTempData.removeAll()
            self.dataModel.initRGBData()
            self.measurementTimer.invalidate()
            self.diffArr.removeAll()
            self.checkArr.removeAll()
        }
    }
    
    private func noneUseRecognitionFace() {
        if self.cropFaceRect != nil {
            if self.dataModel.gTempData.count >= self.preparingSec * 30 && !self.measurementTimer.isValid && self.isReal {
                self.measurementModel.checkRealFace.onNext(true)
                self.cameraSetup.setUpCatureDevice()
                self.collectDatas()
            }
        } else {
            self.measurementModel.checkRealFace.onNext(false)
            self.dataModel.gTempData.removeAll()
            self.diffArr.removeAll()
            self.checkArr.removeAll()
        }
    }
    
    private func addContours(
        for face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        if let rect = self.cropFaceRect,
           let lastFrame = self.lastFrame,
           let faceContour = face.contour(ofType: .face),
           let leftEyeContour = face.contour(ofType: .leftEye),
           let leftEyeBrowTopContour = face.contour(ofType: .leftEyebrowTop),
           let leftEyeBrowBottomContour = face.contour(ofType: .leftEyebrowBottom),
           let rightEyeContour = face.contour(ofType: .rightEye),
           let rightEyeBrowTopContour = face.contour(ofType: .rightEyebrowTop),
           let rightEyeBrowBottomContour = face.contour(ofType: .rightEyebrowBottom),
           let upperLipContour = face.contour(ofType: .upperLipTop),
           let lowerLipContour = face.contour(ofType: .lowerLipBottom),
           let faceCropBuffer = self.croppedSampleBuffer(lastFrame, with: rect),
           let cropImage = OpenCVWrapper.converting(faceCropBuffer) {
            
            var facePath = UIBezierPath().then { p in
                p.lineWidth = 2
            }
            var leftEyePath = UIBezierPath().then { p in
                p.lineWidth = 2
            }
            var rightEyePath = UIBezierPath().then { p in
                p.lineWidth = 2
            }
            var leftEyeBrowPath = UIBezierPath().then { p in
                p.lineWidth = 2
            }
            var rightEyeBrowPath = UIBezierPath().then { p in
                p.lineWidth = 2
            }
            var lipsPath = UIBezierPath().then { p in
                p.lineWidth = 2
            }
            
            draw(
                previewLayer: previewLayer,
                facePoints: faceContour.points,
                leftEyePoints: leftEyeContour.points,
                rightEyePoints: rightEyeContour.points,
                leftEyeBrowPoints: leftEyeBrowTopContour.points + leftEyeBrowBottomContour.points ,
                rightEyeBrowPoints: rightEyeBrowTopContour.points + rightEyeBrowBottomContour.points,
                lipsPoints: upperLipContour.points + lowerLipContour.points,
                cropImage: cropImage,
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
                      let cropImage = cropImage else { return print("crop image return") }
                
                if self.model.willCheckRealFace {
                    checkReal(eyePoints: leftEyePoints)
                } else {
                    self.isReal = true
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
                
                guard let faceCropImage = getMaskedImage(picture: cropImage, cgPath: facePath.cgPath),
                      let sampleBuffer = faceCropImage.createCMSampleBuffer() else { fatalError("face crop image return") }
                
                self.extractRGBFromDetectFace(sampleBuffer: sampleBuffer)
            }
        }
    }
    
    private func extractRGBFromDetectFace(
        sampleBuffer: CMSampleBuffer
    ) {
        guard let faceRGB = OpenCVWrapper.detectFace(sampleBuffer) else {
            print("objc casting error")
            return
        }
        
        guard let r = faceRGB[0] as? Float,
              let g = faceRGB[1] as? Float,
              let b = faceRGB[2] as? Float else {
            print("objc rgb casting error")
            return
        }
        
        let timeStamp = (Date().timeIntervalSince1970 * 1000000).rounded()
        
        if self.measurementTimer.isValid {
            guard timeStamp > 100 else { return }
            self.dataModel.collectRGB(
                timeStamp: timeStamp,
                r: r, g: g, b: b
            )
        } else {
            self.dataModel.gTempData.append(g)
        }
    }
    
    private func checkReal(
        eyePoints: [VisionPoint]
    ) {
        if !self.measurementTimer.isValid {
            let eyeXpoints = eyePoints.map { $0.x },
                maxXpoint = eyeXpoints.max() ?? 0,
                minXpoint = eyeXpoints.min() ?? 0,
                diff = maxXpoint - minXpoint
            self.diffArr.append(diff)
            let avg = self.diffArr.reduce(CGFloat(0), +) / CGFloat(self.diffArr.count)
            let ratio = diff / avg
            let standardRatio = diff < 26 ? 0.8 : 0.6
            let check = ratio < standardRatio ? true : false
            if self.checkArr.count < 150 {
                self.checkArr.append(check)
            } else {
                self.checkArr.removeFirst()
                self.checkArr.append(check)
            }
            self.isReal = self.checkArr.contains(true)
        }
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
    
    private func gridPath(
        previewLayer: AVCaptureVideoPreviewLayer,
        width: CGFloat,
        height: CGFloat,
        points: [VisionPoint],
        path: inout UIBezierPath
    ) {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        for (i, point) in points.enumerated() {
            let cgPoint = normalizedPoint(previewLayer: previewLayer,
                                          fromVisionPoint: point,
                                          width: width,
                                          height: height)
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
    
    private func getMaskedImage(
        picture: UIImage,
        cgPath: CGPath
    ) -> UIImage? {
        let picture = flipImage(picture) ?? picture
        let imageLayer = CALayer()
        imageLayer.frame = CGRect(origin: .zero, size: picture.size)
        imageLayer.contents = picture.cgImage
        let maskLayer = CAShapeLayer()
        let maskPath = cgPath.resized(to: CGRect(origin: .zero, size: picture.size))
        maskLayer.path = maskPath
        maskLayer.fillRule = .evenOdd
        imageLayer.mask = maskLayer
        
        UIGraphicsBeginImageContext(picture.size)
        defer { UIGraphicsEndImageContext() }
        
        if let context = UIGraphicsGetCurrentContext() {
            context.addPath(maskPath ?? cgPath)
            context.clip()
            imageLayer.render(in: context)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            
            return newImage
        }
        return nil
    }
    
    private func flipImage(
        _ image: UIImage
    ) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: image.size.width, y: image.size.height)
        context.scaleBy(x: -image.scale, y: -image.scale)
        context.draw(image.cgImage!, in: CGRect(origin:CGPoint.zero, size: image.size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    // MARK: ImageBuffer crop
    private func croppedSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with rect: CGRect
    ) -> CMSampleBuffer? { // 특정 사이즈만큼 화면을 잘라 카메라 측정을 하기 위한 함수
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let bytesPerPixel = bytesPerRow / width
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
        let baseAddressStart = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var cropX = Int(rect.origin.x)
        let cropY = Int(rect.origin.y)
        
        // Start pixel in RGB color space can't be odd.
        if cropX % 2 != 0 {
            cropX += 1
        }
        
        let cropStartOffset = Int(cropY * bytesPerRow + cropX * bytesPerPixel)
        
        var pixelBuffer: CVPixelBuffer!
        var error: CVReturn
        
        // Initiates pixelBuffer.
        let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
        let options = [kCVPixelBufferCGImageCompatibilityKey: true,
               kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                                      kCVPixelBufferWidthKey: rect.size.width,
                                     kCVPixelBufferHeightKey: rect.size.height] as [CFString : Any]
        
        error = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                             Int(rect.size.width),
                                             Int(rect.size.height),
                                             pixelFormat,
                                             &baseAddressStart[cropStartOffset],
                                             Int(bytesPerRow),
                                             nil,
                                             nil,
                                             options as CFDictionary,
                                             &pixelBuffer)
        if error != kCVReturnSuccess {
            print("Crop CVPixelBufferCreateWithBytes error \(Int(error))")
            return nil
        }
        
        // Cropping using CIImage.
        var ciImage = CIImage(cvImageBuffer: imageBuffer)
        ciImage = ciImage.cropped(to: rect)
        // CIImage is not in the original point after cropping. So we need to pan.
        ciImage = ciImage.transformed(by: CGAffineTransform(translationX: CGFloat(-cropX), y: CGFloat(-cropY)))
        
        guard let pixelBuffer = pixelBuffer else { return nil }
        
        self.gCIContext?.render(ciImage, to: pixelBuffer)
        
        // Prepares sample timing info.
        var sampleTime = CMSampleTimingInfo()
        sampleTime.duration = CMSampleBufferGetDuration(sampleBuffer)
        sampleTime.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        sampleTime.decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        
        var videoInfo: CMVideoFormatDescription!
        error = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                             imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
        if error != kCVReturnSuccess {
            print("CMVideoFormatDescriptionCreateForImageBuffer error \(Int(error))")
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags.readOnly)
            return nil
        }
        
        // Creates `CMSampleBufferRef`.
        var resultBuffer: CMSampleBuffer?
        error = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                   imageBuffer: pixelBuffer,
                                                   dataReady: true,
                                                   makeDataReadyCallback: nil,
                                                   refcon: nil,
                                                   formatDescription: videoInfo,
                                                   sampleTiming: &sampleTime,
                                                   sampleBufferOut: &resultBuffer)
        if error != kCVReturnSuccess {
            print("CMSampleBufferCreateForImageBuffer error \(Int(error))")
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        return resultBuffer
    }
    
    private func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
        
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp || deviceOrientation == .unknown{
            deviceOrientation = self.currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
    
    private func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}
