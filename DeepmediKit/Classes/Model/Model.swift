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
    
    var secretKey: String
    var apiKey: String
    
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
            if self.faceMeasurementTime < 30.0 {
                self.faceMeasurementTime = 30.0
            }
        }
    }
    
    var windowSec: Int
    var overlappingSec: Int
    var age: Int,
        height: Int,
        weight: Int,
        belly: Int,
        act: Int,
        smoke: Int,
        diabetes: Int
    
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
        self.willCheckRealFace = true
        
        self.secretKey = "secretKey"
        self.apiKey = "apiKey"
        
        self.age = 20
        self.gender = 0
        self.height = 160
        self.weight = 60
        self.belly = 0
        self.act = 0
        self.smoke = 0
        self.diabetes = 0
        
        self.faceMeasurementTime = 30.0
        self.windowSec = 15
        self.overlappingSec = 2
        
        self.limitTapTime = 3
        self.limitNoTapTime = 5
        self.fingerMeasurementTime = 30.0
        self.breathMeasurement = true
    }
}

class RecordModel {
    static let shared = RecordModel()
    
    var hr: Int
    var hrGraph: [Float]
    var sys: Int, dia: Int
    var af: Int
    var cardioRisk: [Double]
    
    var msi: Float, psi: Float
    var rmssd: Int
    var sdnn: Int
    
    init() {
        self.hr = 65
        self.psi = 0
        self.msi = 0
        self.sys = 100
        self.dia = 50
        self.af = 0
        self.cardioRisk = []
    
        self.hrGraph = []
        self.rmssd = 0
        self.sdnn = 0
    }
}
