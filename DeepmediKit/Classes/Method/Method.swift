//
//  Method.swift
//  Alamofire
//
//  Created by 딥메디 on 12/22/25.
//

import UIKit
import AVFoundation
import CoreImage

final class SampleBufferConverter {
    private static let ciContext = CIContext(options: nil)

    /// Front camera: BGRA -> UIImage + 90° clockwise + mirrored
    static func convertingBufferFront(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let w = CVPixelBufferGetWidth(pixelBuffer)
        let h = CVPixelBufferGetHeight(pixelBuffer)
        let rect = CGRect(x: 0, y: 0, width: w, height: h)

        guard let cgImage = ciContext.createCGImage(ciImage, from: rect) else { return nil }

        // OpenCV: rotate 90 clockwise + (front camera 미러)
        // - 미러 포함해서 셀카 프리뷰처럼 보이게 하려면 보통 rightMirrored
        return UIImage(
            cgImage: cgImage,
            scale: 1.0,
//            scale: 0.8,
            orientation: .leftMirrored
        )
    }

    /// 평균 RGB를 0...255 스케일로 Double(소수점 6자리) 반환
    static func detectFaceSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> [NSNumber]? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("image not found")
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent

        guard let avgImage = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])?.outputImage else {
            print("image filter error")
            return nil
        }

        // RGBAf (Float32 per channel) 로 렌더 -> [Float] 4개
        var rgbaF = [Float](repeating: 0, count: 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        SampleBufferConverter.ciContext.render(
            avgImage,
            toBitmap: &rgbaF,
            rowBytes: MemoryLayout<Float>.size * 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBAf,                // ✅ 부동소수 포맷
            colorSpace: cs
        )

        // 0...1 → 0...255 변환 후 소수점 6자리로 반올림
        func round6(_ v: Double) -> Float { Float((v * 1.0e6).rounded() / 1.0e6) }
        let r = round6(Double(rgbaF[0]) * 255.0)
        let g = round6(Double(rgbaF[1]) * 255.0)
        let b = round6(Double(rgbaF[2]) * 255.0)

        return [NSNumber(value: r), NSNumber(value: g), NSNumber(value: b)]
    }
}
