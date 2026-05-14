//
//  ㄴtability.swift
//  DeepmediKit
//
//  Created by 딥메디 on 5/13/26.
//

import Foundation

extension FaceKit {
    func setBaselinePose(
        currentPose: HeaderAngles
    ) {
        let limitCount = model.stableFrameCount
        let currentYaw = abs(currentPose.yaw)
        let currentPitch = abs(currentPose.pitch)
        let currentRoll = abs(currentPose.roll)
        guard positionStableCount > limitCount,
              angleStableCount > limitCount,
              currentYaw <= 25,
              currentPitch <= 20,
              currentRoll <= 15 else {
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
