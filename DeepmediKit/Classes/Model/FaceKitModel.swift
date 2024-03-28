//
//  FaceKitModel.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import AVKit

public class FaceKitModel: NSObject {
    let model = Model.shared
    
    public func injectingRecognitionAreaView(
        _ view: UIView,
//        temp: UIView,
        face: UIImageView,
        chest: UIImageView
    ) {
        self.model.faceRecognitionAreaView = view
//        self.model.tempView = temp
        self.model.faceImgView = face
        self.model.chestImgView = chest
    }
    
//    public func willUseFaceRecognitionArea(
//        _ use: Bool
//    ) {
//        self.model.useFaceRecognitionArea = use
//    }
    
    public func setMeasurementTime(
        _ time: Double?
    ) {
        self.model.faceMeasurementTime = time ?? 30.0
    }
    
    public func setWindowSecond(
        _ time: Int?
    ) {
        self.model.windowSec = time ?? 15
    }
    
    public func setOverlappingSecond(
        _ time: Int?
    ) {
        self.model.overlappingSec = time ?? 2
    }
}
