//
//  ㄴtability.swift
//  DeepmediKit
//
//  Created by 딥메디 on 5/13/26.
//

import Foundation

extension FaceKit {
    private var maxMeasurableYaw: CGFloat { 25 }
    private var maxMeasurablePitch: CGFloat { 20 }
    private var maxMeasurableRoll: CGFloat { 15 }
    
    func isWithinPoseThreshold(
        currentPose: HeaderAngles
    ) -> Bool {
        let currentYaw = abs(currentPose.yaw)
        let currentPitch = abs(currentPose.pitch)
        let currentRoll = abs(currentPose.roll)
        return currentYaw <= maxMeasurableYaw
        && currentPitch <= maxMeasurablePitch
        && currentRoll <= maxMeasurableRoll
    }
    
    func setBaselinePose(
        currentPose: HeaderAngles
    ) {
        let limitCount = model.stableFrameCount
        guard positionStableCount > limitCount,
              angleStableCount > limitCount,
              isWithinPoseThreshold(currentPose: currentPose) else {
            return
        }
        baselineHeadAngle = currentPose
    }
    
    func isWithinBaselinePose(
        currentPose: HeaderAngles
    ) -> Bool {
        guard let baselinePose = baselineHeadAngle else {
            return false
        }
        let threshold = model.baselineAngle
        return Int(abs(baselinePose.yaw - currentPose.yaw)) <= threshold
        && Int(abs(baselinePose.pitch - currentPose.pitch)) <= threshold
        && Int(abs(baselinePose.roll - currentPose.roll)) <= threshold
    }
}
