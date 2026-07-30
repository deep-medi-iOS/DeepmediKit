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
        // 코어 처리 중에는 프리뷰 세션을 유지하되 ML Kit/크롭 처리를 생략한다.
        guard !isCoreInferenceRunning else { return }

        recordDeliveredVideoFrame()

        guard let cvimgRef: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("cvimg ref")
            return
        }

        let orientation = imageOrientationMapper.image(fromDevicePosition: .front)
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = orientation
        
        let imageWidth = CGFloat(CVPixelBufferGetWidth(cvimgRef))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(cvimgRef))
        
        detectFacesOnDevice(
            in: visionImage,
            sampleBuffer: sampleBuffer,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        ) // 얼굴인식을 위한 함수
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let reason = CMGetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_DroppedFrameReason,
            attachmentModeOut: nil
        )
        recordDroppedVideoFrame(reason: reason)
    }
    
    // 얼굴인식 구역내 얼굴인식
    private func detectFacesOnDevice(
        in image: VisionImage,
        sampleBuffer: CMSampleBuffer,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) {
        let faces: [Face]
        do {
            faces = try configuredFaceDetector().results(in: image)
        } catch let error {
            print("Failed to detect faces with error: \(error.localizedDescription).")
            return
        }

        let largestDetectedFace = faces.max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }

        // contour는 가장 두드러진 얼굴에만 제공된다. 여러 얼굴의 상태가 한 측정에
        // 섞이지 않도록 contour가 있는 가장 큰 얼굴 하나만 사용한다.
        let primaryFace = faces
            .filter { !$0.contours.isEmpty }
            .max { lhs, rhs in
                lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
            }
        let headPoseFace = resolvedHeadPoseFace(
            in: image,
            preferredFace: primaryFace ?? largestDetectedFace
        )

        performOnMain { [weak self] in
            guard let self else { return }
            self.refreshFaceDetectionConfiguration()

            if let headPoseFace {
                self.publishHeadAngles(from: headPoseFace)
            }
            guard let face = primaryFace else {
                self.registerInvalidFaceFrame()
                return
            }
            self.lastFrame = sampleBuffer

            let previewBounds = self.model.previewLayerBounds == .zero
            ? self.previewLayer.bounds
            : self.model.previewLayerBounds
            let frame = face.frame
            let normalizedRect = CGRect(
                x: frame.origin.x / imageWidth,
                y: frame.origin.y / imageHeight,
                width: frame.width / imageWidth,
                height: frame.height / imageHeight
            )
            let standardizedRect = self.previewLayer.layerRectConverted(
                fromMetadataOutputRect: normalizedRect
            ).standardized
            let recognitionStandardizedRect = CGRect(
                x: standardizedRect.origin.x + previewBounds.origin.x,
                y: standardizedRect.origin.y + previewBounds.origin.y,
                width: standardizedRect.width,
                height: standardizedRect.height
            )

            let didProcessFace = self.recognitionArea(
                face: face,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                recognitionStandardizedRect: recognitionStandardizedRect,
                faceRecognitionAreaView: self.faceRecognitionAreaView
            )
            if didProcessFace {
                self.updatePreviewOverlayViewWithLastFrame()
            }
        }
    }

    private func configuredFaceDetector() -> FaceDetector {
        // 데이터 수집용 얼굴 frame/contour는 어제 사용한 detector 설정을 유지한다.
        // 이 설정을 angle 출력 때문에 변경하면 crop 크기와 구도가 달라질 수 있다.
        let shouldUseClassification = model.willCheckRealFace
        if let faceDetector,
           faceDetectorUsesClassification == shouldUseClassification {
            return faceDetector
        }

        let options = FaceDetectorOptions()
        options.landmarkMode = .none
        options.contourMode = .all
        options.classificationMode = shouldUseClassification ? .all : .none
        options.performanceMode = .fast

        let detector = FaceDetector.faceDetector(options: options)
        faceDetector = detector
        faceDetectorUsesClassification = shouldUseClassification
        return detector
    }

    private func resolvedHeadPoseFace(
        in image: VisionImage,
        preferredFace: Face?
    ) -> Face? {
        if let preferredFace,
           preferredFace.hasHeadEulerAngleX,
           preferredFace.hasHeadEulerAngleY,
           preferredFace.hasHeadEulerAngleZ {
            return preferredFace
        }

        let faces: [Face]
        do {
            faces = try configuredHeadPoseDetector().results(in: image)
        } catch {
            print("Failed to detect head pose with error: \(error.localizedDescription).")
            return nil
        }

        if let preferredFace {
            let preferredCenter = CGPoint(
                x: preferredFace.frame.midX,
                y: preferredFace.frame.midY
            )
            return faces.min { lhs, rhs in
                let lhsDistance = pow(lhs.frame.midX - preferredCenter.x, 2)
                    + pow(lhs.frame.midY - preferredCenter.y, 2)
                let rhsDistance = pow(rhs.frame.midX - preferredCenter.x, 2)
                    + pow(rhs.frame.midY - preferredCenter.y, 2)
                return lhsDistance < rhsDistance
            }
        }

        return faces.max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }
    }

    private func configuredHeadPoseDetector() -> FaceDetector {
        if let headPoseDetector {
            return headPoseDetector
        }

        // contour를 사용하지 않는 이 조합은 crop detector의 결과에 영향을 주지
        // 않으면서 Euler X/Y/Z만 경량으로 계산한다.
        let options = FaceDetectorOptions()
        options.landmarkMode = .none
        options.contourMode = .none
        options.classificationMode = .none
        options.performanceMode = .fast

        let detector = FaceDetector.faceDetector(options: options)
        headPoseDetector = detector
        return detector
    }

    private func performOnMain(_ block: () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
    }

    private func handleUndetectedFace() {
        lastFrame = nil
        cropFaceRect = nil
        isLeftEyeReal = false
        isRightEyeReal = false
        previousFaceFrame = nil
        previousHeadAngle = nil
        baselineHeadAngle = nil
        positionStableCount = 0
        angleStableCount = 0
        preparingSec = model.prepareTime

        initRGBData()
        timerReset()
        antiSpoofingValidator.initialize()
        // registerInvalidFaceFrame()에서 연속된 잘못된 프레임을 이미 확인했다.
        // 여기서 다시 stop 상태 안정화 프레임을 기다리면 이 함수가 한 번만
        // 호출되는 구조상 pending 상태에 머물러 stopMeasurement(true)가
        // 전달되지 않는다. 이탈이 확정된 시점에는 즉시 stop을 발행한다.
        emitMeasurementState(
            stop: true,
            checkRealFace: false,
            requiredStableFrames: 1
        )
    }

    private func registerInvalidFaceFrame() {
        // ML Kit이 한 프레임에서 contour를 놓치거나 경계가 순간 흔들리는 경우는
        // 측정을 즉시 초기화하지 않고 한 프레임까지 허용한다.
        let toleratedInvalidFrames = 1
        guard consecutiveInvalidFaceFrames <= toleratedInvalidFrames else { return }

        consecutiveInvalidFaceFrames += 1
        if consecutiveInvalidFaceFrames > toleratedInvalidFrames {
            handleUndetectedFace()
        }
    }
    
    // 측정 가능한 상태 확인 후 측정함수 실행
    private func updatePreviewOverlayViewWithLastFrame() {
        guard lastFrame != nil else {
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
                    saveMeasurementOutputs()
                }
                preparingSec = preparingSec == 0 ? 0 : preparingSec - 1
            }
        } else {
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
    //얼굴인식 구역안에 얼굴 존재 할때 랜드마트 크롭함수 실행
    private func recognitionArea(
        face: Face,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        recognitionStandardizedRect: CGRect, // 인식된 얼굴 frame
        faceRecognitionAreaView: UIView
    ) -> Bool {
        let previewBounds = model.previewLayerBounds == .zero
        ? previewLayer.bounds
        : model.previewLayerBounds
        let recognitionArea = useFaceRecognitionArea
        ? faceRecognitionAreaView.frame
        : previewBounds

        let isMeasurableFacePosition = faceDetectAreaCondition(
            faceFrame: recognitionStandardizedRect,
            useFaceRecognitionArea: useFaceRecognitionArea,
            recognitionArea: recognitionArea
        )

        guard isMeasurableFacePosition else {
            registerInvalidFaceFrame()
            return false
        }
        consecutiveInvalidFaceFrames = 0

        let isWithinPose = measurementState.headAnglesRelay.value
            .map { isWithinPoseThreshold(currentPose: $0) }
            ?? false
        emitMeasurementState(
            stop: !isWithinPose,
            checkRealFace: false,
            requiredStableFrames: 1
        )
        cropFaceRect = ultraTightFaceCropRect(
            from: face.frame,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        ) // 얼굴인식 위치 계산

        let isStablePosition: Bool
        if let previousFaceFrame {
            isStablePosition = isStableFacePosition(
                previous: previousFaceFrame,
                current: recognitionStandardizedRect
            )
        } else {
            isStablePosition = false
        }

        positionStableCount = isStablePosition ? positionStableCount + 1 : 0
        previousFaceFrame = recognitionStandardizedRect
        processLandmarkCroppedFaceData(
            for: face,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
        return true
    }
    
    private func isStableFacePosition(
        previous: CGRect,
        current: CGRect
    ) -> Bool {
        guard current.width > 0, current.height > 0 else {
            return false
        }
        let threshold = model.stableRatio
        let topDiff    = Double(abs(previous.minY - current.minY) / current.height)
        let bottomDiff = Double(abs(previous.maxY - current.maxY) / current.height)
        let leftDiff   = Double(abs(previous.minX - current.minX) / current.width)
        let rightDiff  = Double(abs(previous.maxX - current.maxX) / current.width)
        return topDiff < threshold
            && bottomDiff < threshold
            && leftDiff < threshold
            && rightDiff < threshold
    }

    private func ultraTightFaceCropRect(
        from faceFrame: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        // 216 기준 얼굴 검출 영역에서 어제 조정한 중앙 100×160 비율만 수집한다.
        let targetWidthRatio: CGFloat = 100.0 / 216.0
        let targetHeightRatio: CGFloat = 160.0 / 216.0
        let insetXRatio = (1.0 - targetWidthRatio) / 2.0
        let insetYRatio = (1.0 - targetHeightRatio) / 2.0

        let standardizedFaceFrame = faceFrame.standardized
        let tightRect = standardizedFaceFrame.insetBy(
            dx: standardizedFaceFrame.width * insetXRatio,
            dy: standardizedFaceFrame.height * insetYRatio
        )

        return tightRect
            .intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            .integral
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
////            self.cropView.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
////            self.landMarkView.frame = CGRect(x: 180, y: 0, width: 120, height: 120)
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

        let useRecognitionArea = useRecognitionArea(
            useSmallViewArea: false,
            minX: minX, maxX: maxX,
            minY: minY, maxY: maxY,
            faceMinX: faceMinX, faceMaxX: faceMaxX,
            faceMinY: faceMinY, faceMaxY: faceMaxY,
            smallMinX: smallMinX, smallMaxX: smallMaxX,
            smallMinY: smallMinY, smallMaxY: smallMaxY
        )
//        (minX <= faceMinX && faceMinX <= smallMinX)
//        && (smallMaxX <= faceMaxX && faceMaxX <= maxX)
//        && (faceMinY <= smallMaxY && smallMinY <= faceMaxY)
        let unUseRecognitionArea = (minX <= faceMinX && faceMinX <= maxX)
        && (minY <= faceMinY && faceMinY <= maxY)
        let areaCondition = useFaceRecognitionArea
        ? useRecognitionArea
        : unUseRecognitionArea
        
        return areaCondition
    }
    
    func useRecognitionArea(
        useSmallViewArea: Bool,
        minX: CGFloat, maxX: CGFloat,
        minY: CGFloat, maxY: CGFloat,
        faceMinX: CGFloat, faceMaxX: CGFloat,
        faceMinY: CGFloat, faceMaxY: CGFloat,
        smallMinX: CGFloat, smallMaxX: CGFloat,
        smallMinY: CGFloat, smallMaxY: CGFloat
    ) -> Bool {
        switch useSmallViewArea {
            case true:
                return (minX <= faceMinX && faceMinX <= smallMinX) && (smallMaxX <= faceMaxX && faceMaxX <= maxX) && (faceMinY <= smallMaxY && smallMinY <= faceMaxY)
            case false:
                return (minX <= faceMinX && faceMaxX <= maxX) && (minY <= faceMinY && faceMaxY <= maxY)
        }
    }
}
