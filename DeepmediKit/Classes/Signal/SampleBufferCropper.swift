//
//  SampleBufferCropper.swift
//  Alamofire
//
//  Created by 딥메디 on 1/5/26.
//

import UIKit
import AVFoundation


final class SampleBufferCropper {
    // MARK: ImageBuffer crop
    // 화면 전체 샘플버퍼에서 얼굴크기만큼만 크롭해서 샘플버퍼 전달
    func sample(
        _ sampleBuffer: CMSampleBuffer,
        with rect: CGRect
    ) -> CMSampleBuffer? {

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
        // ✅ defer로 Unlock을 보장 → early return 시 Unlock 누락 방지

        let bytesPerRow    = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width          = CVPixelBufferGetWidth(imageBuffer)
        let bytesPerPixel  = bytesPerRow / width
        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else { return nil }
        let baseAddressStart = baseAddress.assumingMemoryBound(to: UInt8.self)

        var cropX = Int(rect.origin.x)
        let cropY = Int(rect.origin.y)
        if cropX % 2 != 0 { cropX += 1 }

        let cropStartOffset = cropY * bytesPerRow + cropX * bytesPerPixel

        let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let error = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            Int(rect.size.width),
            Int(rect.size.height),
            pixelFormat,
            &baseAddressStart[cropStartOffset],
            bytesPerRow,
            nil,
            nil,
            options as CFDictionary,
            &pixelBuffer
        )

        guard error == kCVReturnSuccess, let pixelBuffer else {
            print("CVPixelBufferCreateWithBytes error \(error)")
            return nil
        }

        // ✅ 핵심: CMSampleBuffer를 Lock 범위 안에서 완전히 생성
        //    pixelBuffer는 imageBuffer 메모리를 참조하므로
        //    Unlock 전에 CMSampleBuffer까지 만들어야 안전
        var sampleTime = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        )

        var videoInfo: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &videoInfo
        ) == kCVReturnSuccess, let videoInfo else {
            print("CMVideoFormatDescriptionCreateForImageBuffer error")
            return nil
        }

        var resultBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoInfo,
            sampleTiming: &sampleTime,
            sampleBufferOut: &resultBuffer
        ) == kCVReturnSuccess else {
            print("CMSampleBufferCreateForImageBuffer error")
            return nil
        }

        // ✅ resultBuffer 생성 완료 후 defer에 의해 Unlock
        //    이후 CoreImage가 pixelBuffer에 접근하더라도
        //    CMSampleBuffer는 이미 독립적으로 retain되어 있음
        return resultBuffer
    }
}
