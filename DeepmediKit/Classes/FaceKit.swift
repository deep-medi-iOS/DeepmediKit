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
    enum MeasurementErr: Error {
        case message(String)
    }
    private let bag = DisposeBag()
    
    private let makeDocument = Document(),
                measurementModel = MeasurementModel()
    
    private let service = Service.manager
    
    private let dataModel = DataModel.shared,
                model = Model.shared,
                cameraSetup = CameraSetup.shared
    
    private var lastFrame: CMSampleBuffer?,
                gCIContext: CIContext?,
                cropFaceRect: CGRect?,
                cropChestRect: CGRect?
    
    // MARK: Property
    private var preparingSec = Int(), // 얼굴을 인식하고 준비하는 시간
                prepareTimer = Timer(),
                measurementTime = Double(), // 측정하는 시간
                measurementTimer = Timer()
    
    private var previewLayer = AVCaptureVideoPreviewLayer(),
                faceRecognitionAreaView = UIView()
    
    private var notDetectFace = true,
                isPreparing = false,
                isLeftEyeReal = false ,
                isRightEyeReal = false ,
                diffLeftArr:[CGFloat] = [],
                diffRightArr:[CGFloat] = [],
                checkLeftArr:[Bool] = [],
                checkRightArr:[Bool] = []
    
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
    
    public func captureImage(
        _ capture: @escaping((UIImage?) -> ())
    ) {
        let captureImage = measurementModel.captureImage
        captureImage
            .observe(on: MainScheduler.instance)
            .asDriver(onErrorJustReturn: UIImage())
            .drive(onNext: { image in
                capture(image)
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
        _ isSuccess: @escaping((Bool, ([Double], [Float], [Float], [Float])) -> ())
    ) {
        let completion = measurementModel.measurementComplete
        let timeStamp = measurementModel.timeStamp,
            sigR = measurementModel.sigR,
            sigB = measurementModel.sigB,
            sigG = measurementModel.sigG
        
        Observable.combineLatest(
            completion,
            timeStamp,
            sigR,
            sigG,
            sigB
        )
        .observe(on: MainScheduler.instance)
        .asDriver(onErrorJustReturn: (false, [], [], [], []))
        .drive(onNext: { (res, ts, r, g, b) in
            isSuccess(res, (ts, r, g, b))
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
    
//    private var tempView = UIView()
//    private var tempView1 = UIView()
//    private var tempView2 = UIView()

    open func startSession() {
        self.measurementTime = self.model.faceMeasurementTime
        self.preparingSec = self.model.prepareTime
        self.isPreparing = true
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
            if let previewLayer = self.model.previewLayer {
                self.previewLayer = previewLayer
            }
            
            if self.model.useFaceRecognitionArea,
               let faceRecognitionAreaView = self.model.faceRecognitionAreaView {
                self.faceRecognitionAreaView = faceRecognitionAreaView
//                DispatchQueue.main.async {
//                    self.faceRecognitionAreaView.addSubview(self.tempView)
//                    self.faceRecognitionAreaView.addSubview(self.tempView1)
//                    self.faceRecognitionAreaView.addSubview(self.tempView2)
//                    self.tempView = self.faceRecognitionAreaView
//                }
            }
            
            self.cameraSetup.useSession().startRunning()
        }
    }
    
    open func stopSession() {
        self.lastFrame = nil
        self.cropFaceRect = nil
        self.isLeftEyeReal = false
        self.isRightEyeReal = false
        self.isPreparing = false
        
        self.measurementTimer.invalidate()
        self.prepareTimer.invalidate()
//        self.dataModel.initRGBData()
        self.dataModel.gTempData.removeAll()
        self.diffLeftArr.removeAll()
        self.diffRightArr.removeAll()
        self.checkLeftArr.removeAll()
        self.checkRightArr.removeAll()
        
        self.cameraSetup.useCaptureDevice().exposureMode = .autoExpose
        
        DispatchQueue.global(qos: .background).async {
            self.cameraSetup.useSession().stopRunning()
        }
    }
    
    private func collectDatas() {
        self.measurementModel.measurementStop.onNext(false)
        
        let secondRemaining = measurementModel.secondRemaining,
            measurementCompleteRatio = measurementModel.measurementCompleteRatio,
            measurementComplete = measurementModel.measurementComplete,
            timeStamp = measurementModel.timeStamp,
            sigR = measurementModel.sigR,
            sigB = measurementModel.sigB,
            sigG = measurementModel.sigG
        
        self.isPreparing = false
        self.dataModel.initRGBData()
        self.dataModel.gTempData.removeAll()
        
        self.preparingSec = self.model.prepareTime
        self.measurementTime = self.model.faceMeasurementTime
        self.measurementTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { timer in
            guard self.isLeftEyeReal && self.isRightEyeReal else {
                self.diffLeftArr.removeAll()
                self.diffRightArr.removeAll()
                self.checkLeftArr.removeAll()
                self.checkRightArr.removeAll()
//                self.dataModel.gTempData.removeAll()
                timer.invalidate()
                return
            }
            let ratio = Int(100.0 - self.measurementTime * 100.0 / self.model.faceMeasurementTime)
            measurementCompleteRatio.onNext("\(ratio)%")
            secondRemaining.onNext(Int(self.measurementTime))
//            print("[++\(#fileID):\(#line)]- data count : ", self.dataModel.gData.count)
            // MARK: 측정완료
            if self.measurementTime <= 0.0 {
                timer.invalidate()
                self.makeDocument.makeDocument(data: .rgb) //측정한 데이터 파일로 변환
                if let rgbPath = self.dataModel.rgbDataPath { //파일이 존재할때 api호출 시도
                    measurementComplete.onNext(true)
                    timeStamp.onNext(self.dataModel.timeStamp)
                    sigR.onNext(self.dataModel.rData)
                    sigG.onNext(self.dataModel.gData)
                    sigB.onNext(self.dataModel.bData)
                } else {
                    measurementComplete.onNext(false)
                    timeStamp.onNext([])
                    sigR.onNext([])
                    sigG.onNext([])
                    sigB.onNext([])
                }
            }
            self.measurementTime -= 0.1
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
        options.classificationMode = .all
        options.performanceMode = .accurate
        
        let faceDetector = FaceDetector.faceDetector(options: options)
            
            do {
                faces = try faceDetector.results(in: image)
            } catch let error {
                print("Failed to detect faces with error: \(error.localizedDescription).")
                return
            }
        DispatchQueue.global(qos: .background).async {
            
            self.updatePreviewOverlayViewWithLastFrame()
            
//            DispatchQueue.main.sync {
                
                if !faces.isEmpty {
                    
                    for face in faces {
                        
                        guard face.contours.count != 0 else {
                            //                        print("[++\(#fileID):\(#line)]- face frame: ", face.frame)
                            return
                        }
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
                                faceRecognitionAreaView: self.faceRecognitionAreaView
                            )
                            
                        } else {
                            
                            let x1 = (face.frame.origin.x + face.frame.size.width * 0.1),
                                y1 = (face.frame.origin.y + face.frame.size.height * 0.1),
                                w1 = (face.frame.size.width * 0.8),
                                h1 = (face.frame.size.height * 0.8)// 얼굴인식 위치 설정
                            let noneRecognitionNormalizedRect = CGRect(
                                x: x1 / imageWidth,
                                y: y1 / imageHeight,
                                width: w1 / imageWidth,
                                height: h1 / imageHeight
                            )
                            let standardizedRect1 = self.previewLayer.layerRectConverted(
                                fromMetadataOutputRect: noneRecognitionNormalizedRect
                            ).standardized,
                                noneRecgnitionStandardizedRect = CGRect(
                                    x: standardizedRect1.origin.x + previewBounds.origin.x,
                                    y: standardizedRect1.origin.y + previewBounds.origin.y,
                                    width: standardizedRect1.width,
                                    height: standardizedRect1.height
                                )
                            
                            self.noneRecognitionArea(
                                face: face,
                                imageWidth: imageWidth,
                                imageHeight: imageHeight,
                                standardizedRect: noneRecgnitionStandardizedRect
                            )
                        }
                    }
                } else {
                    print("On-Device face detector returned no results.")
                    self.isPreparing = false
                    
                    self.lastFrame = nil
                    self.cropFaceRect = nil
                    self.dataModel.gTempData.removeAll()
                    self.measurementTimer.invalidate()
                    self.prepareTimer.invalidate()
                    
                    self.measurementModel.checkRealFace.onNext(false)
                    self.measurementModel.measurementStop.onNext(true)
                }
            }
//        }
    }
    
    func faceDetectAreaCondition(
        recognitionArea: CGRect,
        faceFrame: CGRect
    ) -> Bool {
        let minX = recognitionArea.minX
        let maxX = recognitionArea.maxX
        let minY = recognitionArea.minY
        let maxY = recognitionArea.maxY
        
        let smallMinX = recognitionArea.minX + (recognitionArea.width / 2.2)
        let smallMaxX = recognitionArea.maxX - (recognitionArea.width / 2.2)
        let smallMinY = recognitionArea.minY + (recognitionArea.height / 2.2)
        let smallMaxY = recognitionArea.maxY - (recognitionArea.height / 2.2)
        
        let faceMinX = faceFrame.minX
        let faceMaxX = faceFrame.maxX
        let faceMinY = faceFrame.minY
        let faceMaxY = faceFrame.maxY
                
//        DispatchQueue.main.async {
//            self.tempView.layer.borderColor = UIColor.red.cgColor
//            self.tempView.layer.borderWidth = 5
//            
//            self.tempView1.layer.borderColor = UIColor.blue.cgColor
//            self.tempView1.layer.borderWidth = 1
//            
//            self.tempView2.layer.borderColor = UIColor.green.cgColor
//            self.tempView2.layer.borderWidth = 1
//            
//            self.tempView.frame = recognitionArea
//            self.tempView1.frame = faceFrame
//            self.tempView2.frame = CGRect(
//                x: smallMinX, y: smallMinY, width: smallMaxX - smallMinX, height: smallMaxY - smallMinY)
//        }
        return (minX <= faceMinX && faceMinX <= smallMinX)
        && (smallMaxX <= faceMaxX && faceMaxX <= maxX)
        && (faceMinY <= smallMaxY && smallMinY <= faceMaxY)
    }
    
    private func recognitionArea(
        face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        recognitionStandardizedRect: CGRect, // 인식된 얼굴 frame
        faceRecognitionAreaView: UIView
    ) {
        DispatchQueue.main.async {
            let betweenFaceFrame = self.faceDetectAreaCondition(
                recognitionArea: faceRecognitionAreaView.frame,
                faceFrame: recognitionStandardizedRect
            )
            if betweenFaceFrame {
                
//        if faceRecognitionAreaView.frame.minX <= recognitionStandardizedRect.minX &&
//            faceRecognitionAreaView.frame.maxX >= recognitionStandardizedRect.maxX &&
//            faceRecognitionAreaView.frame.minY <= recognitionStandardizedRect.minY &&
//            faceRecognitionAreaView.frame.maxY >= recognitionStandardizedRect.maxY {
                
                if let frame = self.lastFrame,
                   let capture = OpenCVWrapper.converting(frame),
                   let faceImage = self.flipImage(capture) {
//                    print("[++\(#fileID):\(#line)]- capture ")
                    self.measurementModel.captureImage.onNext(faceImage)
                }
                
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
                self.dataModel.gTempData.removeAll()
                self.dataModel.initRGBData() // 중간에 쌓여있을 수 있는 데이터 초기화
                self.measurementTimer.invalidate()
                self.prepareTimer.invalidate()
                
                self.preparingSec = self.model.prepareTime
                self.measurementTime = self.model.faceMeasurementTime
                
                self.diffLeftArr.removeAll()
                self.diffRightArr.removeAll()
                self.checkLeftArr.removeAll()
                self.checkRightArr.removeAll()
                self.isPreparing = true
                self.measurementModel.measurementStop.onNext(true)
            }
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
            self.measurementModel.measurementStop.onNext(true)
            self.lastFrame = nil
            self.cropFaceRect = nil
            self.dataModel.gTempData.removeAll()
            self.diffLeftArr.removeAll()
            self.diffRightArr.removeAll()
            self.checkLeftArr.removeAll()
            self.checkRightArr.removeAll()
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
        if self.cropFaceRect != nil && self.isLeftEyeReal && self.isRightEyeReal {
            if self.dataModel.gTempData.count >= 20 {
                self.measurementModel.checkRealFace.onNext(true)
                self.dataModel.gTempData.removeAll()
                self.isPreparing = false
                self.prepareTimer = Timer.scheduledTimer(
                    withTimeInterval: 1,
                    repeats: true
                ) { prepareTimer in
                    self.measurementModel.secondRemaining.onNext(self.preparingSec)
                    if self.preparingSec == 0 {
                        prepareTimer.invalidate()
                        self.cameraSetup.setUpCatureDevice()
                        self.collectDatas()
                    }
                    self.preparingSec -= 1
                }
            }
        } else {
            self.measurementModel.checkRealFace.onNext(false)
//            self.dataModel.gTempData.removeAll()
//            self.diffArr.removeAll()
//            self.checkArr.removeAll()
            self.dataModel.initRGBData()
            self.measurementTimer.invalidate()
            self.prepareTimer.invalidate()
            self.isPreparing = true
        }
    }
    
    private func noneUseRecognitionFace() {
        if self.cropFaceRect != nil && self.isLeftEyeReal && self.isRightEyeReal {
            if self.dataModel.gTempData.count >= 20 && !self.measurementTimer.isValid {
                self.measurementModel.checkRealFace.onNext(true)
                self.cameraSetup.setUpCatureDevice()
                self.collectDatas()
            }
        } else {
            self.measurementModel.checkRealFace.onNext(false)
            self.diffLeftArr.removeAll()
            self.diffRightArr.removeAll()
            self.checkLeftArr.removeAll()
            self.checkRightArr.removeAll()
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
                    checkRealLeftEye(
                        face: face,
                        eyePoints: leftEyePoints
                    )
                    checkRealRightEye(
                        face: face,
                        eyePoints: rightEyePoints
                    )
                } else {
                    self.isLeftEyeReal = true
                    self.isRightEyeReal = true
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
        } else if self.isPreparing {
            self.dataModel.gTempData.append(g)
        }
    }
    
    private func checkRealLeftEye(
        face: Face,
        eyePoints: [VisionPoint]
    ) {
        if !measurementTimer.isValid {
            let leftEyeOpen = face.leftEyeOpenProbability
//                    print("[++\(#fileID):\(#line)]- left eye open: ", leftEyeOpen)
            guard leftEyeOpen != 1.0 else {
                self.isLeftEyeReal = false
                self.checkLeftArr.removeAll()
                self.diffLeftArr.removeAll()
                return
            }
            let check = leftEyeOpen < 0.3
            
            if self.checkLeftArr.count <= 150 {
                self.checkLeftArr.append(check)
            } else {
                self.checkLeftArr.removeFirst()
                self.checkLeftArr.append(check)
            }
            self.isLeftEyeReal = self.checkLeftArr.contains(true)
        }
    }
    
    private func checkRealRightEye(
        face: Face,
        eyePoints: [VisionPoint]
    ) {
        if !measurementTimer.isValid {
            let rightEyeOpen = face.rightEyeOpenProbability
//                    print("[++\(#fileID):\(#line)]- right eye open: ", rightEyeOpen)
            guard rightEyeOpen != 1.0 else {
                self.isRightEyeReal = false
                self.checkRightArr.removeAll()
                self.diffRightArr.removeAll()
                return
            }
            let check = rightEyeOpen < 0.3
            
            if self.checkRightArr.count <= 150 {
                self.checkRightArr.append(check)
            } else {
                self.checkRightArr.removeFirst()
                self.checkRightArr.append(check)
            }
            self.isRightEyeReal = self.checkRightArr.contains(true)
        }
    }
    
    private func checkFacePostion(
        superViewFrame: CGRect,
        faceFrame: CGRect
    ) -> Bool {
        let superViewMinX = superViewFrame.minX,
            superViewMinY = superViewFrame.minY,
            superViewMaxX = superViewFrame.maxX * 3,
            superViewMaxY = superViewFrame.maxY * 3
        
        let faceMinX = faceFrame.minY,
            faceMinY = faceFrame.minX,
            faceMaxX = faceFrame.maxY,
            faceMaxY = faceFrame.maxX
        
        return superViewMinX <= faceMinX && faceMaxX <= superViewMaxX &&
               superViewMinY <= faceMinY && faceMaxY <= superViewMaxY
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
