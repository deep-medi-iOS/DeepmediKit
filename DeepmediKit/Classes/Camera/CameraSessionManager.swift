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
    private let sessionQueue = DispatchQueue(label: "com.deepmedi.DeepmediKit.cameraSession")
    private var customISO: Float?
    private var isExposureLockPending = false
    private var exposureLockGeneration = 0
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
        let preferredPreset: AVCaptureSession.Preset = part == .face
        ? .vga640x480
        : .low
        if session.canSetSessionPreset(preferredPreset) {
            session.sessionPreset = preferredPreset
        }
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
        let fps = framePerSec > 0
        ? framePerSec
        : (part == .face ? 30.0 : 60.0)
        
        for format in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            
            // fps 지원 여부
            let supportsFPS = format.videoSupportedFrameRateRanges.contains { range in
                range.minFrameRate <= fps && fps <= range.maxFrameRate
            }
            guard supportsFPS else { continue }

            switch part {
            case .face:
                // ML Kit contour 검출에 충분하면서 실시간 처리가 가능한 VGA에
                // 가장 가까운 포맷을 선택한다. 480x360 미만은 얼굴 검출 정확도가
                // 크게 떨어질 수 있으므로 후보에서 제외한다.
                guard dims.width >= 480,
                      dims.height >= 360,
                      dims.width <= 1280,
                      dims.height <= 720 else { continue }

                let targetPixels: Int64 = 640 * 480
                let pixels = Int64(dims.width) * Int64(dims.height)
                let distance = abs(pixels - targetPixels)

                if let currentDims = bestDims {
                    let currentPixels = Int64(currentDims.width) * Int64(currentDims.height)
                    let currentDistance = abs(currentPixels - targetPixels)
                    if distance < currentDistance {
                        bestFormat = format
                        bestDims = dims
                    }
                } else {
                    bestFormat = format
                    bestDims = dims
                }
            case .finger:
                guard dims.width <= 700, dims.height <= 700 else { continue }
                if bestFormat == nil
                    || (dims.width * dims.height) > (bestDims!.width * bestDims!.height) {
                    bestFormat = format
                    bestDims = dims
                }
            }
        }
        
        guard let chosen = bestFormat else {
            print("No matching format for fps:", fps)
            return
        }

        // activeFormat을 직접 선택할 때 세션 프리셋이 포맷을 다시 덮어쓰지 않도록 한다.
        if session.canSetSessionPreset(.inputPriority) {
            session.sessionPreset = .inputPriority
        }
        
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.activeFormat = chosen
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps.rounded()))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            if part == .face {
                limitFaceMaximumExposureDuration(device)
            }
        } catch {
            print("lockForConfiguration failed:", error)
        }
        
        if let bestDims {
            print("Chosen format:", part, "\(bestDims.width)x\(bestDims.height) @ \(fps)fps")
        }
        if part == .finger, device.hasTorch {
            correctColor()
        }
    }

    func startRunning() {
        let session = self.session
        sessionQueue.async {
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stopRunning() {
        let session = self.session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }
    
    func setUpCaptureDevice(
        _ mode: AVCaptureDevice.ExposureMode
    ) {
        guard captureDevice?.exposureMode != mode else { return }
        configureCaptureDevice { device in
            guard device.isExposureModeSupported(mode) else { return }
            device.exposureMode = mode
        }
    }

    /// 현재 자동 노출이 선택한 ISO와 노출 시간을 측정용 값으로 고정한다.
    /// setExposureModeCustom의 적용 완료 전에는 false를 반환하므로 호출자는
    /// stop=false 상태를 아직 외부에 발행하면 안 된다.
    func prepareMeasurementExposureLock() -> Bool {
        guard let device = captureDevice else { return false }

        if let customISO {
            let isLockedMode = device.exposureMode == .custom
                || device.exposureMode == .locked
            let tolerance = max(0.1, customISO * 0.001)
            return !isExposureLockPending
                && isLockedMode
                && !device.isAdjustingExposure
                && abs(device.iso - customISO) <= tolerance
        }

        guard !isExposureLockPending else { return false }

        let targetISO = min(max(device.iso, device.activeFormat.minISO), device.activeFormat.maxISO)
        let targetDuration = device.exposureDuration
        exposureLockGeneration += 1
        let generation = exposureLockGeneration
        customISO = targetISO
        isExposureLockPending = true

        let didConfigure = configureCaptureDevice { [weak self] device in
            guard let self else { return }

            if device.isExposureModeSupported(.custom) {
                device.setExposureModeCustom(
                    duration: targetDuration,
                    iso: targetISO
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        guard self.exposureLockGeneration == generation else { return }
                        self.customISO = self.captureDevice?.iso ?? targetISO
                        self.isExposureLockPending = false
                    }
                }
            } else if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
                customISO = device.iso
                isExposureLockPending = false
            } else {
                customISO = nil
                isExposureLockPending = false
            }
        }

        if !didConfigure {
            customISO = nil
            isExposureLockPending = false
        }
        return false
    }

    /// 얼굴을 찾거나 측정 재시작을 기다리는 동안 조명 변화에 대응한다.
    /// 연속 자동 노출을 지원하지 않는 기기에서는 1회 자동 노출로 폴백한다.
    func resumeAutomaticExposure() {
        guard let device = captureDevice else { return }

        exposureLockGeneration += 1
        customISO = nil
        isExposureLockPending = false

        let mode: AVCaptureDevice.ExposureMode
        if device.isExposureModeSupported(.continuousAutoExposure) {
            mode = .continuousAutoExposure
        } else if device.isExposureModeSupported(.autoExpose) {
            mode = .autoExpose
        } else {
            return
        }

        configureCaptureDevice { [weak self] device in
            guard device.isExposureModeSupported(mode) else { return }
            device.exposureMode = mode
            self?.limitFaceMaximumExposureDuration(device)
        }
    }

    /// 얼굴 측정 중 자동 노출이 1/30초보다 느린 셔터를 선택하지 못하게 제한한다.
    /// 기기 포맷의 지원 범위가 더 짧으면 해당 최대값을 사용한다.
    private func limitFaceMaximumExposureDuration(_ device: AVCaptureDevice) {
        let requestedDuration = CMTime(value: 1, timescale: 30)
        let format = device.activeFormat
        let maximumDuration: CMTime

        if CMTimeCompare(requestedDuration, format.minExposureDuration) < 0 {
            maximumDuration = format.minExposureDuration
            print("Face exposure limit unsupported; using format minimum duration:", maximumDuration)
        } else if CMTimeCompare(requestedDuration, format.maxExposureDuration) > 0 {
            maximumDuration = format.maxExposureDuration
        } else {
            maximumDuration = requestedDuration
        }

        device.activeMaxExposureDuration = maximumDuration
    }
    
    func correctColor() {
        configureCaptureDevice { device in
            let gainset = AVCaptureDevice.WhiteBalanceGains(
                redGain: 1.6,
                greenGain: 1.0,
                blueGain: 1.6
            )
            device.setWhiteBalanceModeLocked(
                with: gainset,
                completionHandler: nil
            )
        }
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
