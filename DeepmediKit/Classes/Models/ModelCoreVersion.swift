//
//  ModelCoreVersion.swift
//  DeepmediKit
//
//  Created by DeepmediKit.
//

import Foundation

public enum DeepmediKitModelCore {
    public static let version = "v62"
    public static let baseName = "model_core"
    public static let fileExtension = "tflite"
    public static let modelName = "\(baseName)_\(version)"
    public static let fileName = "\(modelName).\(fileExtension)"

    public static var logDescription: String {
        "\(fileName) version=\(version)"
    }
}
