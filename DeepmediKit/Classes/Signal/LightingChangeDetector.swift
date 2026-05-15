//
//  DerivativeDetector.swift
//  DeepmediKit
//
//  Created by 딥메디 on 5/6/26.
//

import Foundation

final internal class LightingChangeDetector {

    private let threshold: Float
    private let smoothingWindow: Int
    private var prevBrightness: Float?
    private var derivativeBuffer: [Float] = []

    init(
        threshold: Float = 2.0,
        smoothingWindow: Int = 5
    ) {
        precondition(smoothingWindow > 0, "smoothingWindow must be a positive number.")
        self.threshold = threshold
        self.smoothingWindow = smoothingWindow
    }

    func update(
        sigR: Float,
        sigG: Float,
        sigB: Float
    ) -> FaceKit.LightingChangeDetectorResult {
        let brightness =
            Self.luminanceRCoeff * sigR +
            Self.luminanceGCoeff * sigG +
            Self.luminanceBCoeff * sigB

        guard let prev = prevBrightness else {
            prevBrightness = brightness
            return FaceKit.LightingChangeDetectorResult(
                changed: false,
                rawDerivative: 0.0,
                smoothedDerivative: 0.0,
                brightness: brightness
            )
        }
        
        let rawDerivative = abs(brightness - prev)
        derivativeBuffer.append(rawDerivative)
        
        if derivativeBuffer.count > smoothingWindow {
            derivativeBuffer.removeFirst()
        }

        prevBrightness = brightness
        let smoothedDerivative =
            derivativeBuffer.reduce(0.0, +) / Float(derivativeBuffer.count)
        
        return FaceKit.LightingChangeDetectorResult(
            changed: smoothedDerivative > threshold,
            rawDerivative: rawDerivative,
            smoothedDerivative: smoothedDerivative,
            brightness: brightness
        )
    }

    func reset() {
        prevBrightness = nil
        derivativeBuffer.removeAll()
    }
}

private extension LightingChangeDetector {
    static let luminanceRCoeff: Float = 0.299
    static let luminanceGCoeff: Float = 0.587
    static let luminanceBCoeff: Float = 0.114
}
