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
    
    var uiImageToCVPixelBuffer: CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        let attrs = [
            String(kCVPixelBufferCGImageCompatibilityKey): false,
            String(kCVPixelBufferCGBitmapContextCompatibilityKey): false,
        ] as CFDictionary
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attrs,
                                         &buffer)
        guard status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(buffer!, CVPixelBufferLockFlags(rawValue: 0))

        return buffer
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
        let boundingBox = self.boundingBox
        let boundingBoxAspectRatio = boundingBox.width / boundingBox.height
        let viewAspectRatio = rect.width / rect.height
        let scaleFactor = boundingBoxAspectRatio > viewAspectRatio ?
            rect.width / boundingBox.width :
            rect.height / boundingBox.height
        let useScale = scaleFactor * 0.8
        
        let scaledSize = boundingBox.size.applying(CGAffineTransform(scaleX: useScale, y: useScale))
        let centerOffset = CGSize(
            width: (rect.width - scaledSize.width) / (useScale * 2),
            height: (rect.height - scaledSize.height) / (useScale * 2)
        )

        var transform = CGAffineTransform.identity
            .scaledBy(x: useScale, y: useScale)
            .translatedBy(x: -boundingBox.minX + centerOffset.width, y: -boundingBox.minY + centerOffset.height)
        
        return copy(using: &transform)
    }
}

extension UIDevice {
    var identifier: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        let identifier = String(bytes: data, encoding: .ascii)!
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
    
    var modelName: String {
        return modelNameMappingList[identifier] ?? "Unknown"
    }
    
    private var modelNameMappingList: [String: String] {
        return [
            /***************************************************
             iPhone
             ***************************************************/
            "iPhone8,4" : "iPhone SE (GSM)",
            "iPhone9,1" : "iPhone 7",
            "iPhone9,2" : "iPhone 7 Plus",
            "iPhone9,3" : "iPhone 7",
            "iPhone9,4" : "iPhone 7 Plus",
            "iPhone10,1" : "iPhone 8",
            "iPhone10,2" : "iPhone 8 Plus",
            "iPhone10,3" : "iPhone X Global",
            "iPhone10,4" : "iPhone 8",
            "iPhone10,5" : "iPhone 8 Plus",
            "iPhone10,6" : "iPhone X GSM",
            "iPhone11,2" : "iPhone XS",
            "iPhone11,4" : "iPhone XS Max",
            "iPhone11,6" : "iPhone XS Max Global",
            "iPhone11,8" : "iPhone XR",
            "iPhone12,1" : "iPhone 11",
            "iPhone12,3" : "iPhone 11 Pro",
            "iPhone12,5" : "iPhone 11 Pro Max",
            "iPhone12,8" : "iPhone SE 2nd Gen",
            "iPhone13,1" : "iPhone 12 Mini",
            "iPhone13,2" : "iPhone 12",
            "iPhone13,3" : "iPhone 12 Pro",
            "iPhone13,4" : "iPhone 12 Pro Max",
            "iPhone14,2" : "iPhone 13 Pro",
            "iPhone14,3" : "iPhone 13 Pro Max",
            "iPhone14,4" : "iPhone 13 Mini",
            "iPhone14,5" : "iPhone 13",
            "iPhone14,6" : "iPhone SE 3rd Gen",
            "iPhone14,7" : "iPhone 14",
            "iPhone14,8" : "iPhone 14 Plus",
            "iPhone15,2" : "iPhone 14 Pro",
            "iPhone15,3" : "iPhone 14 Pro Max",
            "iPad11,1" : "iPad mini 5th Gen (WiFi)",
            "iPad14,1" : "iPad mini 6th Gen (WiFi)",
            "iPad13,4" : "iPad Pro 11 inch 5th Gen",
            "iPad13,5" : "iPad Pro 11 inch 5th Gen",
            "iPad13,6" : "iPad Pro 11 inch 5th Gen",
            "iPad13,7" : "iPad Pro 11 inch 5th Gen",
        ]
    }
}
