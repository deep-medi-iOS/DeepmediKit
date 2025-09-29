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
    
    private var part = CameraObject.Part.finger
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
    func startDetection(
        _ part: CameraObject.Part
    ) {
        session.sessionPreset = .low
        
        if part == .face {
            guard let captureDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .front
            ) else { fatalError("capture device error") }
            detection(captureDevice)
            
        } else {
            
            if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                detection(captureDevice)
            } else if let captureDevice1 = AVCaptureDevice.default(for: .video) {
                detection(captureDevice1)
            } else { // iOS version 13.0 이하
                guard let captureDevice = AVCaptureDevice.default(for: .video) else { fatalError("capture device error") }
                detection(captureDevice)
            }
        }
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
        _ part: CameraObject.Part,
        _ framePerSec: Double
    ) {
        var currentFormat: AVCaptureDevice.Format?,
            tempFramePerSec = Double()
        
        guard let captureDeviceFormats = captureDevice?.formats else { fatalError("capture device") }
        self.part = part
        for format in captureDeviceFormats {
            let ranges = format.videoSupportedFrameRateRanges
            let frameRates = ranges[0]
            let videoFormatDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            
            if (frameRates.maxFrameRate == framePerSec) {
                if part == .face {
                    if videoFormatDimensions.width <= Int32(2000) && videoFormatDimensions.height <= Int32(1100) {
                        currentFormat = format
                        tempFramePerSec = 30.0
                    }
                } else {
                    if videoFormatDimensions.width <= Int32(700) && videoFormatDimensions.height <= Int32(500) {
                        currentFormat = format
                        tempFramePerSec = framePerSec
                    }
                }
            } else {
                tempFramePerSec = 30.0
                if part == .face {
                    if videoFormatDimensions.width <= Int32(2000) && videoFormatDimensions.height <= Int32(1100)  {
                        currentFormat = format
                    }
                } else {
                    if videoFormatDimensions.width <= Int32(700) && videoFormatDimensions.height <= Int32(500)  {
                        currentFormat = format
                    }
                }
            }
        }
        
        guard let tempCurrentFormat = currentFormat,
              try! captureDevice?.lockForConfiguration() != nil else { return print("current format")}
        
        try! captureDevice?.lockForConfiguration()
        captureDevice?.activeFormat = tempCurrentFormat
        captureDevice?.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(tempFramePerSec))
        captureDevice?.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(tempFramePerSec))
        captureDevice?.unlockForConfiguration()
        
        guard part == .finger, captureDevice?.hasTorch ?? false else { return }
            correctColor()
    }
    
    func setUpCatureDevice() {
        try! captureDevice?.lockForConfiguration()
        if device.modelName.contains("X") && part == .finger {
            captureDevice?.exposureMode = .custom
            captureDevice?.setExposureModeCustom(duration: CMTime(value: 1, timescale: 60) , iso: 24.0)
        } else {
            captureDevice?.exposureMode = .locked
        }
        captureDevice?.unlockForConfiguration()
    }
    
    func clearCaptureDevice() {
        try! captureDevice?.lockForConfiguration()
        captureDevice?.exposureMode = .autoExpose
        captureDevice?.unlockForConfiguration()
    }
    
    func correctColor() {
        try! self.captureDevice?.lockForConfiguration()
        let gainset = AVCaptureDevice.WhiteBalanceGains(redGain: 1.6,
                                                        greenGain: 1.0, // 3 -> 1 edit
                                                        blueGain: 1.6)
        self.captureDevice?.setWhiteBalanceModeLocked(with: gainset,
                                                      completionHandler: nil)
        self.captureDevice?.unlockForConfiguration()
    }
    
    func setupVideoOutput(
        _ part: CameraObject.Part,
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
        videoOutput.alwaysDiscardsLateVideoFrames = part == .face
        
        if self.session.canAddOutput(videoOutput) {
            self.session.addOutput(videoOutput)
        } else {
            print("can not output")
        }
    }
}
