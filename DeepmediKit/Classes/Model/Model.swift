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
    
    var secretKey: String
    var apiKey: String
    
    var limitTapTime: Int
    var limitNoTapTime: Int
    var fingerMeasurementTime: Double
    var breathMeasurement: Bool
        
    var useFaceRecognitionArea: Bool
    var willCheckRealFace: Bool
    
    var tempView = UIView()
    var faceImgView = UIImageView()
    var chestImgView = UIImageView()
    
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
        
        self.secretKey = "secretKey"
        self.apiKey = "apiKey"
        
        self.age = 20
        self.gender = 0
        self.height = 160
        self.weight = 60
        
        self.faceMeasurementTime = 15.0
        self.prepareTime = 1
        self.windowSec = 15
        self.overlappingSec = 2
        
        self.limitTapTime = 3
        self.limitNoTapTime = 5
        self.fingerMeasurementTime = 30.0
        self.breathMeasurement = true
        self.willCheckRealFace = true
    }
}

class RecordModel {
    static let shared = RecordModel()
    
    var hr: Int
    var sys: Int, dia: Int
    var af: Int
    var physicalStress: Float,
        mentalStress: Float
    
    var breath: Int
    var spo2: Int
    
    var cardioRisk: Double
    
    init() {
        self.hr = 65
        self.physicalStress = 0
        self.mentalStress = 0
        self.sys = 10
        self.dia = 10
        self.af = 0
        self.cardioRisk = 0
        self.breath = 10
        self.spo2 = 10
    }
}
