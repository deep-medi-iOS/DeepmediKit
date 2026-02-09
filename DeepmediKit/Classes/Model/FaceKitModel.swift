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
        _ view: UIView
    ) {
        self.model.faceRecognitionAreaView = view
    }
    
    public func willUseFaceRecognitionArea(
        _ use: Bool
    ) {
        self.model.useFaceRecognitionArea = use
    }
    
    public func willCheckRealFace(
        _ check: Bool
    ) {
        self.model.willCheckRealFace = check
    }
    
    public func setMeasurementTime(
        _ time: Double?
    ) {
        self.model.faceMeasurementTime = time ?? 15.0
    }
    
    public func setPrepareTime(
        _ time: Int?
    ) {
        self.model.prepareTime = time ?? 1
    }
}
