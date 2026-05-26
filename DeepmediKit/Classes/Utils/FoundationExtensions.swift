//
//  Extension.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

extension UIImage {
    enum type: String {
        case ciImage, uiImage
    }
    var ciImageToCVPixelBuffer: CVPixelBuffer? {
        if let ciImage = CIImage(image: self) {
            let attrs = [
                String(kCVPixelBufferCGImageCompatibilityKey): false,
                String(kCVPixelBufferCGBitmapContextCompatibilityKey): false,
            ] as CFDictionary
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                             Int(ciImage.extent.width),
                                             Int(ciImage.extent.height),
                                             kCVPixelFormatType_32BGRA,
                                             attrs,
                                             &buffer)
            
            guard (status == kCVReturnSuccess) else {
                return nil
            }
            
            let context = CIContext()
            context.render(ciImage, to: buffer!)
            
            return buffer
        }
        return nil
    }

    func createCMSampleBuffer() -> CMSampleBuffer? {
        guard let pixelBuffer = ciImageToCVPixelBuffer else { fatalError("pixel buffer return") }
        var timimgInfo = CMSampleTimingInfo()
        var videoInfo: CMVideoFormatDescription?
        var newSampleBuffer: CMSampleBuffer?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
                                                     imageBuffer: pixelBuffer,
                                                     formatDescriptionOut: &videoInfo)
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                           imageBuffer: pixelBuffer,
                                           dataReady: true,
                                           makeDataReadyCallback: nil,
                                           refcon: nil,
                                           formatDescription: videoInfo!,
                                           sampleTiming: &timimgInfo,
                                           sampleBufferOut: &newSampleBuffer)
        return newSampleBuffer!
    }
}

extension CGPath {
    func resized(
        to rect: CGRect
    ) -> CGPath? {
        // ✅ 더 안정적인 bbox (곡선 control point 때문에 boundingBox가 튀는 문제 방지)
        let inset = 1.0
        let bbox = self.boundingBoxOfPath
            guard bbox.width > 0.0001, bbox.height > 0.0001 else { return nil }

            let sx = rect.width / bbox.width
            let sy = rect.height / bbox.height
            let s  = min(sx, sy) * inset

            let scaledW = bbox.width * s
            let scaledH = bbox.height * s

            // 최종 rect 기준 중앙정렬 오프셋
            let tx = (rect.width  - scaledW) * 0.5
            let ty = (rect.height - scaledH) * 0.5

            var t = CGAffineTransform.identity

            // ✅ 중앙정렬 이동은 "scale 전에" 먼저 넣는다 (scale 영향 안 받게)
            t = t.translatedBy(x: tx, y: ty)

            // ✅ 그 다음 scale
            t = t.scaledBy(x: s, y: s)

            // ✅ 마지막으로 bbox 원점을 (0,0)으로 당기기 (이 값은 scale 기준이므로 그대로)
            t = t.translatedBy(x: -bbox.minX, y: -bbox.minY)

            return self.copy(using: &t)
    }
}

extension UIDevice {
    var identifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let data = Data(bytes: &systemInfo.machine, count: Int(_SYS_NAMELEN))
        let raw = String(bytes: data, encoding: .ascii) ?? "Unknown"
        return raw.trimmingCharacters(in: .controlCharacters)
    }

    var modelName: String {
        return identifier
    }
}
