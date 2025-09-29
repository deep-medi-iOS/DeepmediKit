//
//  FingerKitModel.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit

public class FingerKitModel: NSObject {
    let model = Model.shared

    public func setMeasurementTime(
        _ time: Double?
    ) {
        self.model.fingerMeasurementTime = time ?? 15.0
    }
    
    public func doMeasurementBreath(
        _ measurement: Bool
    ) {
        self.model.breathMeasurement = measurement
    }
}
