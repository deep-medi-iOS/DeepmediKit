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
        guard positionStableCount > limitCount, angleStableCount > limitCount, baselineHeadAngle == nil else {
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
        let threshold = model.faceAngle
        return Int(abs(baselinePose.yaw - currentPose.yaw)) <= threshold
            && Int(abs(baselinePose.pitch - currentPose.pitch)) <= threshold
            && Int(abs(baselinePose.roll - currentPose.roll)) <= threshold
    }
}
