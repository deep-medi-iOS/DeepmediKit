//
//  CameraSetup.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

class CameraSetup: NSObject {
    static let shared = CameraSetup()

    private var session = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private var customISO: Float?
    private let device = UIDevice.current
    
    func initModel(
        session: AVCaptureSession,
        captureDevice: AVCaptureDevice?
    ) {
        self.session = session
        self.captureDevice = captureDevice
    }
    
    func useSession() -> AVCaptureSession {
        return self.session
    }
    
    func useCaptureDevice() -> AVCaptureDevice {
        guard let device = captureDevice else { return AVCaptureDevice(uniqueID: "tmp")! }
        return device
    }
    
    func hasTorch() -> Bool {
        guard let device = captureDevice else { return false }
        return device.hasTorch
    }
    
    @available(iOS 10.0, *)
    func startDetection() {
        session.sessionPreset = .low
        guard let captureDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else { fatalError("capture device error") }
        detection(captureDevice)
    }
    
    private func detection(
        _ captureDevice: AVCaptureDevice
    ) {
        self.captureDevice = captureDevice
        
        if session.inputs.isEmpty {
            guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { fatalError("input error") }
            session.addInput(input)
        }
    }
    
    func setupCameraFormat(
        _ framePerSec: Double
    ) {
//        var currentFormat: AVCaptureDevice.Format?
//        
//        guard let captureDeviceFormats = captureDevice?.formats else { fatalError("capture device") }
//        
//        for format in captureDeviceFormats {
//            let ranges = format.videoSupportedFrameRateRanges
//            let frameRates = ranges[0]
//            let videoFormatDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)    
//            if videoFormatDimensions.width <= Int32(2000) && videoFormatDimensions.height <= Int32(1100) {
//                print("[++\(#fileID):\(#line)]- format: ", format)
//                currentFormat = format
//            }
//        }
//        
//        guard let tempCurrentFormat = currentFormat,
//              try! self.captureDevice?.lockForConfiguration() != nil else { return print("current format")}
//        self.captureDevice?.activeFormat = tempCurrentFormat
//        self.captureDevice?.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(30))
//        self.captureDevice?.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(30))
//        self.captureDevice?.unlockForConfiguration()
        guard let device = captureDevice else { return }

            var bestFormat: AVCaptureDevice.Format?
            var bestDims: CMVideoDimensions?

            for format in device.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)

                // 해상도 조건
                guard dims.width <= 2000, dims.height <= 1100 else { continue }

                // fps 지원 여부
                let supportsFPS = format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= 30 && 30 <= range.maxFrameRate
                }
                guard supportsFPS else { continue }

                // 예: 가장 큰 해상도 우선 선택
                if bestFormat == nil || (dims.width * dims.height) > (bestDims!.width * bestDims!.height) {
                    bestFormat = format
                    bestDims = dims
                }
            }

            guard let chosen = bestFormat else {
                print("No matching format for fps:", 30)
                return
            }

            do {
                try device.lockForConfiguration()
                device.activeFormat = chosen
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(30))
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(30))
                device.unlockForConfiguration()
            } catch {
                print("lockForConfiguration failed:", error)
            }

            print("Chosen format:", chosen)
    }
    
    func setUpCaptureDevice(
        _ mode: AVCaptureDevice.ExposureMode
    ) {
        try! self.captureDevice?.lockForConfiguration()
        captureDevice?.exposureMode = mode
        captureDevice?.unlockForConfiguration()
    }
    
    func setupVideoOutput(
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate
    ) {
        let videoOutput = AVCaptureVideoDataOutput()
        let captureQueue = DispatchQueue(label: "catpureQueue")
        
        videoOutput.setSampleBufferDelegate(
            delegate,
            queue: captureQueue
        )
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if self.session.canAddOutput(videoOutput) {
            self.session.addOutput(videoOutput)
        } else {
            print("can not output")
        }
    }
    
    func setMovieFileOutput(movieOutput: AVCaptureMovieFileOutput) {
        if self.session.canAddOutput(movieOutput) {
            self.session.addOutput(movieOutput)
        } else {
            print("can not movieOutput")
        }
    }
}
