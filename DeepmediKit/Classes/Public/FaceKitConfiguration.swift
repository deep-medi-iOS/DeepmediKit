//
//  FaceKitConfiguration.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import AVKit

public class FaceKitConfiguration: NSObject {
    let model = FaceKitConfigurationStore.shared
    
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
    
    public func setMeasurementDataCount(
        _ count: Int?
    ) {
        self.model.measurementDataCount = count ?? 450
    }
    
    public func setPrepareTime(
        _ time: Int?
    ) {
        self.model.prepareTime = time ?? 1
    }
    
    public func setStatbleRatio(
        _ ratio: Double?
    ) {
        self.model.stableRatio = ratio ?? 0.05
    }
    
    public func setFaceAngle(
        _ angle: Int?
    ) {
        self.model.faceAngle = angle ?? 5
    }
    
    public func setBaselineAngle(
        _ angle: Int?
    ) {
        self.model.baselineAngle = angle ?? 10
    }
    public func setStableFrameCount(
        _ count: Int?
    ) {
        self.model.stableFrameCount = count ?? 3
    }
}
