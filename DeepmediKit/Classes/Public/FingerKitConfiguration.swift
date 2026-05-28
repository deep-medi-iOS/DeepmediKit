//
//  FingerKitConfiguration.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit

public class FingerKitConfiguration: NSObject {
    let model = ConfigurationStore.shared

    public func setMeasurementDataCount(
        _ count: Int?
    ) {
        self.model.measurementFingerDataCount = count ?? 900
    }

    public func setLimitTapTime(
        _ count: Int?
    ) {
        self.model.limitTapTime = max(1, count ?? 3)
    }

    public func setLimitNoTapTime(
        _ count: Int?
    ) {
        self.model.limitNoTapTime = max(1, count ?? 6)
    }

    @available(*, deprecated, message: "Finger completion now follows measurementDataCount.")
    public func setMeasurementTime(
        _ time: Double?
    ) {
//        self.model.fingerMeasurementTime = max(5.0, time ?? 15.0)
    }

    public func doMeasurementBreath(
        _ measurement: Bool
    ) {
        self.model.breathMeasurement = measurement
    }
}
