//
//  Model.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import AVKit
import RxSwift

class Model {
    static let shared = Model()
    
    var measurePart: CameraObject.Part = .face
    
    var limitTapTime: Int
    var limitNoTapTime: Int
    var fingerMeasurementTime: Double
    var breathMeasurement: Bool
    
    var useFaceRecognitionArea: Bool
    var willCheckRealFace: Bool
    
    var faceRecognitionAreaView: UIView?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerBounds: CGRect
    
    var faceMeasurementTime: Double {
        didSet {
            if self.faceMeasurementTime < 15.0 {
                self.faceMeasurementTime = 15.0
            }
        }
    }
    var prepareTime: Int
    
    init() {
        self.faceRecognitionAreaView = UIView()
        self.previewLayer = AVCaptureVideoPreviewLayer()
        self.previewLayerBounds = CGRect()
        
        self.useFaceRecognitionArea = true
        self.willCheckRealFace = true
        
        self.faceMeasurementTime = 15.0
        self.prepareTime = 1
        
        self.limitTapTime = 3
        self.limitNoTapTime = 5
        self.fingerMeasurementTime = 30.0
        self.breathMeasurement = true
    }
}
