//
//  CameraSessionManager.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

class CameraSessionManager: NSObject {
    static let shared = CameraSessionManager()
    
    private var session = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private let captureQueue = DispatchQueue(label: "captureQueue")
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
    
    func isTorchOn() -> Bool {
        guard let device = captureDevice, device.hasTorch else { return false }
        return device.torchMode == .on
    }
    
    @available(iOS 10.0, *)
    func startDetection(
        _ part: CameraDeviceController.Part
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
                self.detection(captureDevice)
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
        _ part: CameraDeviceController.Part,
        _ framePerSec: Double
    ) {
        guard let device = captureDevice else { return }
        
        var bestFormat: AVCaptureDevice.Format?
        var bestDims: CMVideoDimensions?
        let fps = part == .face ? 30.0 : 60.0
        
        for format in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            
            // 해상도 조건
            guard dims.width <= 2000, dims.height <= 1100 else { continue }
            
            // fps 지원 여부
            let supportsFPS = format.videoSupportedFrameRateRanges.contains { range in
                range.minFrameRate <= fps && fps <= range.maxFrameRate
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
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            device.unlockForConfiguration()
        } catch {
            print("lockForConfiguration failed:", error)
        }
        
        print("Chosen format:", part, chosen)
        if part == .finger, device.hasTorch {
            correctColor()
        }
    }
    
    func setUpCaptureDevice(
        _ mode: AVCaptureDevice.ExposureMode
    ) {
        try! self.captureDevice?.lockForConfiguration()
        captureDevice?.exposureMode = mode
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
    
    func setTorchMode(enabled: Bool) -> Bool {
        var didApply = false
        configureCaptureDevice { device in
            guard device.hasTorch else {
                print("has not torch")
                return
            }
            let mode: AVCaptureDevice.TorchMode = enabled ? .on : .off
            guard device.isTorchModeSupported(mode) else {
                print("torch mode is not supported: \(mode.rawValue)")
                return
            }
            device.torchMode = mode
            didApply = true
        }
        return didApply
    }
    
    @discardableResult
    private func configureCaptureDevice(
        _ block: (AVCaptureDevice) -> Void
    ) -> Bool {
        guard let device = captureDevice else {
            print("capture device is nil")
            return false
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            block(device)
            return true
        } catch {
            print("lockForConfiguration failed:", error)
            return false
        }
    }
    
    func setupVideoOutput(
        _ part: CameraDeviceController.Part,
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate
    ) {
        if let existingOutput = session.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput {
            existingOutput.setSampleBufferDelegate(delegate, queue: captureQueue)
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()

        videoOutput.setSampleBufferDelegate(
            delegate,
            queue: captureQueue
        )
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            print("can not output")
            return
        }
    }
    
    func clearVideoOutputDelegate(
        _ part: CameraDeviceController.Part,
        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate? = nil
    ) {
        guard let videoOutput = session.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput else {
            return
        }
        if let delegate {
            guard let currentDelegate = videoOutput.sampleBufferDelegate as AnyObject?,
                  currentDelegate === (delegate as AnyObject) else {
                return
            }
        }
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
    }
    
    func setMovieFileOutput(movieOutput: AVCaptureMovieFileOutput) {
        if self.session.canAddOutput(movieOutput) {
            self.session.addOutput(movieOutput)
        } else {
            print("can not movieOutput")
        }
    }
}
