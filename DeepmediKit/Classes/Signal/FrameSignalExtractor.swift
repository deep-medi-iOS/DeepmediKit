//
//  ExtractRGB.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation
import UIKit
import MLKitFaceDetection

// MARK: RGB / ByteArray / YUA -> Ymean / Capture Image
extension FaceKit {
    //크롭된 얼굴이미지에서 RGB 추출
    internal func extractRGBFromDetectFace(
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
            guard ts > 100,
            measurementDataCount > sigR.count else { return }
            let dataSet:(Double, Float, Float, Float) = (ts, r, g, b)
            timeStamp.append(ts)
            sigR.append(r)
            sigG.append(g)
            sigB.append(b)
            totalData.append(dataSet)
            let result = lightingChangeDetector.update(
                sigR: r, sigG: g, sigB: b
            )
            if result.changed {
                print("[++\(#fileID):\(#line)]- is lighting changed! ")
                lightingChangeDetector.reset()
                cropFaceRect = nil
            }
        } else if !isTimerRunning {
            tempG.append(g)
        }
    }
    //byteArray로 수집
    internal func collectionByteData(
        sampleBuffer: CMSampleBuffer,
        timestampUS: UInt64? = nil,
        orientation: UIImage.Orientation? = nil
    ) {
        guard let frameData = SampleBufferConverter.faceBinFrame36x36(
            sampleBuffer,
            timestampUS: timestampUS,
            orientation: orientation
        ) else {
            return print("objc chest casting error")
        }
        frames.append(frameData)
        bytesArray.append(frameData.rgb36x36)
        frameTimestampUS.append(frameData.timestampUS)
    }
    //이미지 밝기 정보
    internal func extractYUVFromDetectFace(
        sampleBuffer: CMSampleBuffer,
        face: Face,
        cropLandMarkFace: UIImage
    ) {
        let yMean = SampleBufferConverter.extractYUVFromDetectFace(sampleBuffer)
        let headAngles = extractHeadAngles(from: face)
        let pitch = headAngles.pitch
        let yaw = headAngles.yaw
        let roll = headAngles.roll
        let device = cameraSessionManager.useCaptureDevice()
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
        
        measurementState.headAnglesRelay.accept(
            HeaderAngles.init(
                pitch: pitch,
                yaw: yaw,
                roll: roll
            )
        )
        measurementState.metaData.accept(
            .init(
                iso: iso,
                exposureMode: expousreState,
                focusMode: focusState,
                whiteBalanceMode: wbState,
            )
        )
        measurementState.yMean.onNext(yMean)
        
        let isStableAngle: Bool
        if let previousHeadAngles = previousHeadAngle {
            isStableAngle = isStableHeadAngle(
                previous: previousHeadAngles,
                current: headAngles
            )
        } else {
            isStableAngle = false
        }
        
        angleStableCount = isStableAngle ? angleStableCount + 1 : 0
        previousHeadAngle = headAngles
    }
    
    private func extractHeadAngles(from face: Face) -> HeaderAngles {
        return HeaderAngles(
            pitch: face.headEulerAngleX, // 위/아래
            yaw: face.headEulerAngleY,   // 좌/우 회전
            roll: face.headEulerAngleZ   // 좌/우 기울기(tilt)
        )
    }
    
    private func isStableHeadAngle(
        previous: HeaderAngles,
        current: HeaderAngles
    ) -> Bool {
        let threshold = model.faceAngle
        return Int(abs(previous.yaw - current.yaw)) <= threshold
            && Int(abs(previous.pitch - current.pitch)) <= threshold
            && Int(abs(previous.roll - current.roll)) <= threshold
    }
    
    private func modeState(mode: Int) -> String {
        return mode == 0
        ? "LOCKED"
        : mode == 1
        ? "AUTO"
        : "CONTINUOUS"
    }
}
