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
    
    /// OpenCV equivalent:
    /// resize(36x36) -> grayscale -> rotate 90 CW
    /// Returns: 36*36 = 1296 bytes
    static func dataSampleBuffer36x36(_ sampleBuffer: CMSampleBuffer) -> [UInt8]? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }
        
        // 1) 36x36로 스케일 변환(리사이즈)
        let targetW: CGFloat = 36
        let targetH: CGFloat = 36
        let sx = targetW / extent.width
        let sy = targetH / extent.height
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        
        // 2) 36x36 영역만 렌더링
        var out = [UInt8](repeating: 0, count: 36 * 36)
        
        // 3) CoreImage에서 1채널 8-bit로 뽑기 (iOS 17+에서 .R8 / .L8 사용 가능)
        // format 지원이 애매한 OS가 있을 수 있어 아래처럼 "가능하면 R8"로 시도
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        // 주의: CIContext의 render는 포맷 지원이 기기/OS에 따라 달라질 수 있음
        // R8이 안되면 아래 대체안(ARGB8888 → 후처리) 참고
        SampleBufferConverter.ciContext.render(
            resized,
            toBitmap: &out,
            rowBytes: 36, // 1byte * width
            bounds: CGRect(x: 0, y: 0, width: 36, height: 36),
            format: .R8,
            colorSpace: colorSpace
        )
        
        return out
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
            print("[++\(#fileID):\(#line)]- in YUV 420 format ")
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

