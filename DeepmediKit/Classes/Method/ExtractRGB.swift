//
//  ExtractRGB.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation
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
            guard ts > 100 else { return }
            let dataSet:(Double, Float, Float, Float) = (ts, r, g, b)
            timeStamp.append(ts)
            sigR.append(r)
            sigG.append(g)
            sigB.append(b)
            totalData.append(dataSet)
            let result = lightingChangeDetector.update(
                sigR: r,
                sigG: g,
                sigB: b
            )
            if result.changed {
                measurementModel.lightingChange.onNext(
                    .init(
                        changed: result.changed,
                        rawDerivative: result.rawDerivative,
                        smoothedDerivative: result.smoothedDerivative,
                        brightness: result.brightness
                    )
                )
            }
        } else if !isTimerRunning {
            tempG.append(g)
        }
    }
    //byteArray로 수집 -> 260415 수정중
    internal func collectionByteData(
        sampleBuffer: CMSampleBuffer
    ) {
        guard let byteData = SampleBufferConverter.dataSampleBuffer36x36(sampleBuffer) else {
            return print("objc chest casting error")
        }
        bytesArray.append(Array(byteData))
    }
    //이미지 밝기 정보
    internal func extractYUVFromDetectFace(
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
    
    private func modeState(mode: Int) -> String {
        return mode == 0
        ? "LOCKED"
        : mode == 1
        ? "AUTO"
        : "CONTINUOUS"
    }
}
