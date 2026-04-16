//
//  ScreenCapture.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation
//현재화면 캡쳐
//얼굴확인용으로 사용
extension FaceKit {
    internal func screenCapture() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let frame = lastFrame,
               let captureImage = SampleBufferConverter.convertingBufferFront(frame) {
                measurementModel.captureImage.onNext((screen: captureImage, crop: cropFaceImage))
            }
        }
    }
}
