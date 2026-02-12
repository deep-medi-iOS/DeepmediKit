//
//  CameraObject.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

public class CameraObject: NSObject {
    let cameraSetup = CameraSetup.shared
    let model = Model.shared
    
    public func initalized(
        delegate object: AVCaptureVideoDataOutputSampleBufferDelegate,
        session: AVCaptureSession,
        captureDevice: AVCaptureDevice?
    ) {
        self.cameraSetup.initModel(
            session: session,
            captureDevice: captureDevice
        )
        
        self.cameraSetup.startDetection()
        self.cameraSetup.setupCameraFormat(30.0)
        self.cameraSetup.setupVideoOutput(object)
    }
}
