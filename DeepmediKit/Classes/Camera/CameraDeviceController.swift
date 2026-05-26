//
//  CameraDeviceController.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

public class CameraDeviceController: NSObject {
    public enum Part: String {
        case face, finger
    }
    
    let cameraSessionManager = CameraSessionManager.shared
    let model = ConfigurationStore.shared
    
    public func initalized(
        part: CameraDeviceController.Part,
        delegate object: AVCaptureVideoDataOutputSampleBufferDelegate,
        session: AVCaptureSession,
        captureDevice: AVCaptureDevice?
    ) {
        self.cameraSessionManager.initModel(
            session: session,
            captureDevice: captureDevice
        )
        
        self.cameraSessionManager.startDetection(part)
        self.cameraSessionManager.setupCameraFormat(part, part == .face ? 30.0 : 60.0)
        self.cameraSessionManager.setupVideoOutput(part, object)
        self.model.measurePart = part
    }
}
