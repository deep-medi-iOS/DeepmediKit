//
//  Model.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import AVKit
import MLKitFaceDetection

class Model {
    static let shared = Model()
    
    var measurePart: CameraObject.Part = .face
    
    var limitTapTime: Int
    var limitNoTapTime: Int
    var fingerMeasurementTime: Double
    var breathMeasurement: Bool
        
    var useFaceRecognitionArea: Bool
    
    var tempView = UIView()
    var faceImgView = UIImageView()
    var chestImgView: UIImageView?
    
    var faceRecognitionAreaView: UIView?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var previewLayerBounds: CGRect

    var faceMeasurementTime: Double {
        didSet {
            if self.faceMeasurementTime < 30.0 {
                self.faceMeasurementTime = 30.0
            }
        }
    }
    
    var windowSec: Int
    var overlappingSec: Int
    var age: Int,
        height: Int,
        weight: Int
    var gender: Int {
        didSet {
            if self.gender != 0 || self.gender != 1 {
                self.gender = 0
            }
        }
    }
    
    init() {
        self.faceRecognitionAreaView = UIView()
        self.previewLayer = AVCaptureVideoPreviewLayer()
        self.previewLayerBounds = CGRect()
        
        self.useFaceRecognitionArea = true
        
        self.age = 20
        self.gender = 0
        self.height = 160
        self.weight = 60
        
        self.faceMeasurementTime = 30.0
        self.windowSec = 15
        self.overlappingSec = 2
        
        self.limitTapTime = 3
        self.limitNoTapTime = 5
        self.fingerMeasurementTime = 30.0
        self.breathMeasurement = true
        
        self.chestImgView = UIImageView()
    }
}
