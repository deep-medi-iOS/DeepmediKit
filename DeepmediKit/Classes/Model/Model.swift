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
    
    var measurementDataCount: Int {
        didSet {
            if self.measurementDataCount < 450 {
                self.measurementDataCount = 450
            }
        }
    }
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
        
        self.measurementDataCount = 450
        self.prepareTime = 1
        
        self.stableRatio = 0.05
        self.faceAngle = 5
        self.baselineAngle = 10
        self.stableFrameCount = 3
    }
}
