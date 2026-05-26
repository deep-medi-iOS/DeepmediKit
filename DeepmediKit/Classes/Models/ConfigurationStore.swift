//
//  Model.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import AVKit
import RxSwift

class ConfigurationStore {
    static let shared = ConfigurationStore()
    
    var measurePart: CameraDeviceController.Part = .face
    
    var measurementDataCount: Int {
        didSet {
            if self.measurePart == .face {
                if self.measurementDataCount < 450 {
                    self.measurementDataCount = 450
                }
            } else {
                if self.measurementDataCount < 900 {
                    self.measurementDataCount = 900
                }
            }
        }
    }
    var limitTapTime: Int
    var limitNoTapTime: Int
//    var fingerMeasurementTime: Double
    var breathMeasurement: Bool

    var prepareTime: Int
    
    var useFaceRecognitionArea: Bool
    var willCheckRealFace: Bool
    
    var faceRecognitionAreaView: UIView?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerBounds: CGRect
    
    var stableRatio: Double
    var stableFrameCount: Int
    var faceAngle: Int
    var baselineAngle: Int
    
    
    init() {
        self.faceRecognitionAreaView = UIView()
        self.previewLayer = AVCaptureVideoPreviewLayer()
        self.previewLayerBounds = CGRect()
        
        self.useFaceRecognitionArea = true
        self.willCheckRealFace = true
        
        self.measurementDataCount = measurePart == .face ? 450 : 900
        self.prepareTime = 1

        self.limitTapTime = 3
        self.limitNoTapTime = 6
//        self.fingerMeasurementTime = 15.0
        self.breathMeasurement = true
        
        self.stableRatio = 0.05
        self.faceAngle = 5
        self.baselineAngle = 10
        self.stableFrameCount = 3
    }
}
