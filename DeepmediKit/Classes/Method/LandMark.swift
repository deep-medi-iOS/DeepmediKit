//
//  LandMark.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation
import MLKitFaceDetection
import MLKitVision

// MARK: 랜드마크 제거
extension FaceKit {
    //얼굴의 랜드마크를 크롭하고 크롭된 얼굴이미지를 RGB추출 함수로 전달
    internal func processLandmarkCroppedFaceData(
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
           
//                collectionByteData(sampleBuffer: sampleBuffer)
                extractRGBFromDetectFace(sampleBuffer: sampleBuffer)
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
    //랜드마크 구역그리기
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
    //현재 화면크기에 맞춰 이미지 사이즈 노멀라이징
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
    //이미지에서 얼굴 부분만 추출
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

