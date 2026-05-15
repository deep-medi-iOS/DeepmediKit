//
//  CameraDeviceController.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

public class CameraDeviceController: NSObject {
    let cameraSessionManager = CameraSessionManager.shared
    let model = FaceKitConfigurationStore.shared
    
    public func initalized(
        delegate object: AVCaptureVideoDataOutputSampleBufferDelegate,
        session: AVCaptureSession,
        captureDevice: AVCaptureDevice?
    ) {
        self.cameraSessionManager.initModel(
            session: session,
            captureDevice: captureDevice
        )
        
        self.cameraSessionManager.startDetection()
        self.cameraSessionManager.setupCameraFormat(30.0)
        self.cameraSessionManager.setupVideoOutput(object)
    }
}
