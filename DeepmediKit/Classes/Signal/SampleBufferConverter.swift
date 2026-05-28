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

    struct FaceBinFrame {
        let rgb36x36: [UInt8]   // 36 * 36 * 3 (RGB)
        let timestampUS: UInt64 // capture timestamp in microseconds
    }
    
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
//            scale: 1.0,
            scale: 0.8,
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
    
    /// 36x36 RGB frame bytes for face.bin
    /// Returns: 36*36*3 = 3888 bytes (RGB interleaved)
    static func dataSampleBuffer36x36(_ sampleBuffer: CMSampleBuffer) -> [UInt8]? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        // extent origin이 0이 아닐 때 생기는 검정 offset만 제거하고,
        // 이후에는 한 번의 render로 36x36을 만든다.
        let normalizedImage = ciImage.transformed(
            by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
        )
        let targetW: CGFloat = 36
        let targetH: CGFloat = 36
        let resized = normalizedImage.transformed(
            by: CGAffineTransform(
                scaleX: targetW / extent.width,
                y: targetH / extent.height
            )
        )

        var rgba = [UInt8](repeating: 0, count: 36 * 36 * 4)
        SampleBufferConverter.ciContext.render(
            resized,
            toBitmap: &rgba,
            rowBytes: 36 * 4,
            bounds: CGRect(x: 0, y: 0, width: 36, height: 36),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var rgb = [UInt8](repeating: 0, count: 36 * 36 * 3)
        for i in 0..<(36 * 36) {
            rgb[(i * 3) + 0] = rgba[(i * 4) + 0]
            rgb[(i * 3) + 1] = rgba[(i * 4) + 1]
            rgb[(i * 3) + 2] = rgba[(i * 4) + 2]
        }
        return rgb
    }

    /// Extract one face.bin frame payload from sampleBuffer.
    static func faceBinFrame36x36(
        _ sampleBuffer: CMSampleBuffer,
        timestampUS: UInt64? = nil
    ) -> FaceBinFrame? {
        guard let rgb = dataSampleBuffer36x36(sampleBuffer) else {
            return nil
        }
        let tsUS = timestampUS ?? sampleBufferTimestampUS(sampleBuffer)
        return FaceBinFrame(rgb36x36: rgb, timestampUS: tsUS)
    }

    /// Build face.bin bytes:
    /// [uint64_be width][uint64_be height][uint64_be frame_count]
    /// [frame bytes...][timestamps uint64_be...]
    static func makeFaceBinData(_ frames: [FaceBinFrame]) -> Data? {
        guard !frames.isEmpty else { return nil }
        guard frames.allSatisfy({ $0.rgb36x36.count == 36 * 36 * 3 }) else { return nil }

        var data = Data()
        data.reserveCapacity((8 * 3) + (frames.count * 36 * 36 * 3) + (8 * frames.count))

        appendBEUInt64(36, to: &data)
        appendBEUInt64(36, to: &data)
        appendBEUInt64(UInt64(frames.count), to: &data)

        for frame in frames {
            data.append(contentsOf: frame.rgb36x36)
        }
        let baseTimestamp = frames.first?.timestampUS ?? 0
        for frame in frames {
            appendBEUInt64(frame.timestampUS &- baseTimestamp, to: &data)
        }
        return data
    }

    static func writeFaceBin(_ frames: [FaceBinFrame], to fileURL: URL) throws {
        guard let data = makeFaceBinData(frames) else {
            throw NSError(
                domain: "SampleBufferConverter",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid frame data for face.bin"]
            )
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private static func appendBEUInt64(_ value: UInt64, to data: inout Data) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { raw in
            data.append(contentsOf: raw)
        }
    }

    static func sampleBufferTimestampUS(_ sampleBuffer: CMSampleBuffer) -> UInt64 {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if pts.isValid {
            let seconds = CMTimeGetSeconds(pts)
            if seconds.isFinite && seconds >= 0 {
                return UInt64((seconds * 1_000_000.0).rounded())
            }
        }
        return UInt64((Date().timeIntervalSince1970 * 1_000_000.0).rounded())
    }
    
    // MARK: YUV 추출
    static func extractYUVFromDetectFace(
        _ sampleBuffer: CMSampleBuffer
    ) -> Float {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get pixel buffer")
            return 0.0
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        // YUV 420 포맷 처리 (일반적으로 카메라에서 사용)
        if pixelFormat == kCVPixelFormatType_32BGRA {
            // Y plane
            guard let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                print("Failed to get Y plane")
                return 0.0
            }
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            
            // Y 평균값 계산
            var ySum: Float = 0
            var yCount = 0
            for row in stride(from: 0, to: yHeight, by: 8) {
                let row = yBaseAddress.advanced(by: row * yBytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in stride(from: 0, to: yWidth, by: 8) {
                    let i = x * 4
                    // 빠르게 근사: G만 써도 밝기 추정에는 대체로 충분
                    ySum += Float(row[i + 1]) // G
                    yCount += 1
                }
//                let rowData = yBaseAddress + row * yBytesPerRow
//                for col in 0..<yWidth {
//                    let yValue = rowData.load(fromByteOffset: col, as: UInt8.self)
//                    ySum += Float(yValue)
//                    yCount += 1
//                }
            }
            return ySum / Float(yCount)
        }
        return 0.0
    }
}
