//
//  SampleBufferDelegate.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation
import MLKitVision
import MLKitFaceDetection

// MARK: 카메라 이미지에서 데이터 수집을 위한 delegate
@available(iOS 13.0, *)
extension FaceKit: AVCaptureVideoDataOutputSampleBufferDelegate {
    //avcapture 사용 프레임워크
    //얼굴 인식 후 얼굴이미지 가져오는데 사용
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
    
        let orientation = imageOrientationMapper.image(fromDevicePosition: .front)
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
    
    // 얼굴인식 구역내 얼굴인식
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
//                        print("[++\(#fileID):\(#line)]- face have not contours")
                        return
                    }
                    if let currentPreviewLayer = self.model.previewLayer {
                        self.previewLayer = currentPreviewLayer
                    }
                    let previewBounds = self.model.previewLayerBounds == .zero
                    ? UIScreen.main.bounds
                    : self.model.previewLayerBounds
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
                self.antiSpoofingValidator.initialize()
                self.emitMeasurementState(stop: true, checkRealFace: false)
            }
        }
    }
    
    // 측정 가능한 상태 확인 후 측정함수 실행
    private func updatePreviewOverlayViewWithLastFrame() {
        DispatchQueue.main.sync { [weak self] in
            guard let self, lastFrame != nil else {
                print("sample buffer error")
                return
            }
            guard let currentPose = measurementState.headAnglesRelay.value else {
                print("[++\(#fileID):\(#line)]- currentPose is nil ")
                return
            }
            let isWithinPose = isWithinPoseThreshold(
                currentPose: currentPose
            )
            setBaselinePose(currentPose: currentPose)
            // MARK: Metadata
            if cropFaceRect != nil
                && isLeftEyeReal
                && isRightEyeReal
                && isWithinPose
                && isWithinBaselinePose(currentPose: currentPose) {
                guard tempG.count >= 30 else { return }
                emitMeasurementState(stop: false, checkRealFace: true)
                tempG.removeAll()
                isTimerRunning = true
                prepareTimer = Timer.scheduledTimer(
                    withTimeInterval: 1,
                    repeats: true
                ) {[weak self] prepareTimer in
                    guard let self else { return }
                    measurementState.secondRemaining.onNext(preparingSec)
                    if preparingSec == 0 {
                        prepareTimer.invalidate()
                        baselineHeadAngle = nil
                        previousFaceFrame = nil
                        previousHeadAngle = nil
                        screenCapture()
                        cameraSessionManager.setUpCaptureDevice(.locked)
                        saveMeasurementOutputs()
                    }
                    preparingSec = preparingSec == 0 ? 0 : preparingSec - 1
                }
            } else {
                cameraSessionManager.setUpCaptureDevice(.autoExpose)
                if !isWithinPose {
                    emitMeasurementState(
                        stop: true,
                        checkRealFace: false,
                        requiredStableFrames: 1
                    )
                    initRGBData()
                    isTimerRunning = false
                    dispatchTimer?.cancel()
                    measurementTimer.invalidate()
                    prepareTimer.invalidate()
                } else if cropFaceRect == nil {
                    emitMeasurementState(stop: true, checkRealFace: false)
                    initRGBData()
                    isTimerRunning = false
                    dispatchTimer?.cancel()
                    measurementTimer.invalidate()
                    prepareTimer.invalidate()
                } else {
                    emitMeasurementState(
                        stop: false,
                        checkRealFace: false,
                        requiredStableFrames: 1
                    )
                }
            }
        }
    }
    //얼굴인식 구역안에 얼굴 존재 할때 랜드마트 크롭함수 실행
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
                    let isWithinPose = self.measurementState.headAnglesRelay.value
                        .map { self.isWithinPoseThreshold(currentPose: $0) }
                        ?? false
                    self.emitMeasurementState(
                        stop: !isWithinPose,
                        checkRealFace: false,
                        requiredStableFrames: 1
                    )
                self.cropFaceRect = CGRect(
                    x: face.frame.origin.x,
                    y: face.frame.origin.y,
                    width: face.frame.width,
                    height: face.frame.height
                ).integral // 얼굴인식 위치 계산
                
                
                let isStablePosition: Bool
                if let previousFaceFrame = previousFaceFrame {
                    isStablePosition = isStableFacePosition(
                        previous: previousFaceFrame,
                        current: recognitionStandardizedRect,
                        imageWidth: face.frame.width,
                        imageHeight: face.frame.height
                    )
                } else {
                    isStablePosition = false
                }
                
                positionStableCount = isStablePosition ? positionStableCount + 1 : 0
                previousFaceFrame = recognitionStandardizedRect
                self.processLandmarkCroppedFaceData(
                    for: face,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight
                )
            } else {
                self.lastFrame = nil
                self.cropFaceRect = nil
                
                self.preparingSec = self.model.prepareTime
                
                self.initRGBData()
                self.timerReset()
                self.antiSpoofingValidator.initialize()
                self.emitMeasurementState(stop: true, checkRealFace: false)
            }
        }
    }
    
    private func isStableFacePosition(
        previous: CGRect,
        current: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> Bool {
        guard imageWidth > 0, imageHeight > 0 else {
            return false
        }
        let threshold = model.stableRatio
        let topDiff    = Double(abs(previous.minY - current.minY) / imageHeight)
        let bottomDiff = Double(abs(previous.maxY - current.maxY) / imageHeight)
        let leftDiff   = Double(abs(previous.minX - current.minX) / imageWidth)
        let rightDiff  = Double(abs(previous.maxX - current.maxX) / imageWidth)
        return topDiff < threshold
            && bottomDiff < threshold
            && leftDiff < threshold
            && rightDiff < threshold
    }
    
    //얼굴인식구역 설정 -> 얼굴 보다 큰 바깥구역(외부구역) 하나와 얼굴보다 작은 안쪽구역(내부구역) 하나 설정
    //얼굴은 외부구역보다는 안쪽, 내부구역보다는 바깥쪽에 존재해야 함
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
}
