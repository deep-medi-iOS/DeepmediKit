
//
//  CameraSetup.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

//class TestCameraSetup: NSObject {
//    static let shared = CameraSetup()
//
//    private var faceSession = AVCaptureSession()
//    private var faceCaptureDevice: AVCaptureDevice?
//
//    private var fingerSession = AVCaptureSession()
//    private var fingerCaptureDevice: AVCaptureDevice?
//
//    private var session = AVCaptureSession()
//    private var captureDevice: AVCaptureDevice?
//
//    private var customISO: Float?
//    private let device = UIDevice.current
//
//    func initModel(
//        part: CameraObject.Part,
//        session: AVCaptureSession,
//        captureDevice: AVCaptureDevice?
//    ) {
////        if part == .face {
////            self.faceSession = session
////            self.faceCaptureDevice = captureDevice
////        } else {
////            self.fingerSession = session
////            self.fingerCaptureDevice = captureDevice
////        }
//
//        self.session = session
//        self.captureDevice = captureDevice
//    }
//
//    func useSession(
//        _ part: CameraObject.Part
//    ) -> AVCaptureSession {
//        return part == .face ? faceSession : fingerSession
//    }
//
//    func useCaptureDevice(
//        _ part: CameraObject.Part
//    ) -> AVCaptureDevice? {
//        return part == .face ? faceCaptureDevice : fingerCaptureDevice
//    }
//
//    func hasTorch() -> Bool {
//        guard let torch = self.fingerCaptureDevice?.hasTorch else { return false }
//        return torch
//    }
//
//    @available(iOS 10.0, *)
//    func startDetection(
//        _ part: CameraObject.Part
//    ) {
//        self.faceSession.sessionPreset = .low
//        self.fingerSession.sessionPreset = .low
//
//        if part == .face {
//            guard let captureDevice = AVCaptureDevice.default(
//                .builtInWideAngleCamera,
//                for: .video,
//                position: .front
//            ) else { fatalError("capture device error") }
//
//            self.detection(part, captureDevice)
//
//        } else {
//
//            if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
//                self.detection(part, captureDevice)
//            } else if let captureDevice1 = AVCaptureDevice.default(for: .video) {
//                self.detection(part,captureDevice1)
//            } else { // iOS version 13.0 이하
//                guard let captureDevice = AVCaptureDevice.default(for: .video) else { fatalError("capture device error") }
//                self.detection(part,captureDevice)
//            }
//        }
//    }
//
//    private func detection(
//        _ part: CameraObject.Part,
//        _ captureDevice: AVCaptureDevice
//    ) {
//        if part == .face {
//            self.faceCaptureDevice = captureDevice
//
//            if self.faceSession.inputs.isEmpty {
//                guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { fatalError("input error") }
//                self.faceSession.addInput(input)
//            }
//        } else {
//            self.fingerCaptureDevice = captureDevice
//
//            if self.fingerSession.inputs.isEmpty {
//                guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { fatalError("input error") }
//                self.fingerSession.addInput(input)
//            }
//        }
//    }
//
//    func setupFaceCameraFormat(
//        _ framePerSec: Double
//    ) {
//        var currentFormat: AVCaptureDevice.Format?,
//            tempFramePerSec = Double()
//
//        guard let captureDeviceFormats = self.faceCaptureDevice?.formats else { fatalError("capture device") }
//
//        for format in captureDeviceFormats {
//            let ranges = format.videoSupportedFrameRateRanges
//            let frameRates = ranges[0]
//
//            if (frameRates.maxFrameRate == framePerSec) {
//                let videoFormatDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//                if videoFormatDimensions.width <= Int32(2000) && videoFormatDimensions.height <= Int32(1100) {
//
//                    currentFormat = format
//                    tempFramePerSec = 30.0
//                }
//            }
//        }
//
//        guard let tempCurrentFormat = currentFormat,
//              try! self.faceCaptureDevice?.lockForConfiguration() != nil else { return print("current format")}
//
//        try! self.faceCaptureDevice?.lockForConfiguration()
//        self.faceCaptureDevice?.activeFormat = tempCurrentFormat
//        self.faceCaptureDevice?.activeVideoMinFrameDuration = CMTimeMake(
//            value: 1,
//            timescale: Int32(tempFramePerSec)
//        )
//        self.faceCaptureDevice?.activeVideoMaxFrameDuration = CMTimeMake(
//            value: 1,
//            timescale: Int32(tempFramePerSec)
//        )
//        self.faceCaptureDevice?.unlockForConfiguration()
//    }
//
//    func setupFingerCameraFormat(
//        _ framePerSec: Double
//    ) {
//        var currentFormat: AVCaptureDevice.Format?,
//            tempFramePerSec = Double()
//
//        guard let captureDeviceFormats = self.fingerCaptureDevice?.formats else { fatalError("capture device") }
//
//        for format in captureDeviceFormats {
//            let ranges = format.videoSupportedFrameRateRanges
//            let frameRates = ranges[0]
//            let videoFormatDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//
//            if (frameRates.maxFrameRate == framePerSec) {
//
//                if ((videoFormatDimensions.width <= Int32(700) &&
//                     videoFormatDimensions.height <= Int32(500))) {
//                    currentFormat = format
//                    tempFramePerSec = framePerSec
//                }
//            } else {
//                if ((videoFormatDimensions.width <= Int32(700) &&
//                     videoFormatDimensions.height <= Int32(500))) {
//
//                    currentFormat = format
//                    tempFramePerSec = 30.0
//                }
//            }
//        }
//
//        guard let tempCurrentFormat = currentFormat,
//              try! self.fingerCaptureDevice?.lockForConfiguration() != nil else { return print("current format")}
//
//        try! self.fingerCaptureDevice?.lockForConfiguration()
//        self.fingerCaptureDevice?.activeFormat = tempCurrentFormat
//        self.fingerCaptureDevice?.activeVideoMinFrameDuration = CMTime(
//            value: 1,
//            timescale: Int32(tempFramePerSec)
//        )
//        self.fingerCaptureDevice?.activeVideoMaxFrameDuration = CMTime(
//            value: 1,
//            timescale: Int32(tempFramePerSec)
//        )
//        self.fingerCaptureDevice?.unlockForConfiguration()
//
//        if self.fingerCaptureDevice?.hasTorch ?? false {
//            self.correctColor()
//        }
//    }
//
//    func setUpFaceCatureDevice() {
//        try! self.faceCaptureDevice?.lockForConfiguration()
//        faceCaptureDevice?.exposureMode = .locked
//        faceCaptureDevice?.unlockForConfiguration()
//    }
//
//    func setUpFingerCatureDevice() {
//        try! self.fingerCaptureDevice?.lockForConfiguration()
//        fingerCaptureDevice?.exposureMode = .locked
//        fingerCaptureDevice?.unlockForConfiguration()
//    }
//
//    func correctColor() {
//        try! self.fingerCaptureDevice?.lockForConfiguration()
//        let gainset = AVCaptureDevice.WhiteBalanceGains(redGain: 1.0,
//                                                        greenGain: 1.0, // 3 -> 1 edit
//                                                        blueGain: 1.0)
//        self.fingerCaptureDevice?.setWhiteBalanceModeLocked(with: gainset,
//                                                      completionHandler: nil)
//        self.fingerCaptureDevice?.unlockForConfiguration()
//    }
//
//    func setupVideoOutput(
//        _ part: CameraObject.Part,
//        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate
//    ) {
//        let videoOutput = AVCaptureVideoDataOutput()
//        let captureQueue = DispatchQueue(label: "catpureQueue")
//
//        videoOutput.setSampleBufferDelegate(
//            delegate,
//            queue: captureQueue
//        )
//        videoOutput.videoSettings = [
//            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)
//        ]
//        videoOutput.alwaysDiscardsLateVideoFrames = part == .face
//
//        if part == .face {
//            if self.faceSession.canAddOutput(videoOutput) {
//                self.faceSession.addOutput(videoOutput)
//            } else {
//                print("can not output")
//            }
//        } else {
//            if self.fingerSession.canAddOutput(videoOutput) {
//                self.fingerSession.addOutput(videoOutput)
//            } else {
//                print("can not output")
//            }
//        }
//    }
//}

