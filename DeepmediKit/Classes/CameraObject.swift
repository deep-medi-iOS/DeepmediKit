//
//  CameraObject.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import Foundation
import AVKit

public class CameraObject: NSObject {
    public enum Part: String {
        case face, finger
    }
    
    let cameraSetup = CameraSetup.shared
    let model = Model.shared
    
    public func initalized(
        part: CameraObject.Part,
        delegate object: AVCaptureVideoDataOutputSampleBufferDelegate,
        session: AVCaptureSession,
        captureDevice: AVCaptureDevice?
    ) {
        self.cameraSetup.initModel(
            session: session,
            captureDevice: captureDevice
        )
        
        self.cameraSetup.startDetection(part)
        self.cameraSetup.setupCameraFormat(part, part == .face ? 30.0 : 60.0)
        self.cameraSetup.setupVideoOutput(part, object)
        self.model.measurePart = part
    }
}
