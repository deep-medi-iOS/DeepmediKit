//
//  Orient.swift
//  Alamofire
//
//  Created by 딥메디 on 1/5/26.
//

import AVFoundation
import AVKit

final class Orientation {
    // 얼굴 회전 관련
    func flipPathHorizontally(_ path: CGPath, in size: CGSize) -> CGPath {
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: size.width, y: 0)
        t = t.scaledBy(x: -1, y: 1)
        return path.copy(using: &t) ?? path
    }
    func flipImage(
        _ image: UIImage
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale  // 원본 스케일 유지
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: image.size.width, y: 0)
            c.scaleBy(x: -1, y: 1)
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    // 디바이스 회전에 맞춰 얼굴 회원 -> 사실상 세워서만 사용 하도록
    func image(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
        
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown
            || deviceOrientation == .faceUp
            || deviceOrientation == .unknown {
            deviceOrientation = currentUI()
        }
        switch deviceOrientation {
            case .portrait:
                return .leftMirrored
//            return devicePosition == .front ? .leftMirrored : .right
            case .landscapeLeft:
                return devicePosition == .front ? .downMirrored : .up
            case .portraitUpsideDown:
                return devicePosition == .front ? .rightMirrored : .left
            case .landscapeRight:
                return devicePosition == .front ? .upMirrored : .down
            case .faceDown, .faceUp, .unknown:
                return .up
            @unknown default:
                fatalError()
        }
    }
    //화면 좌우 반전 설정
    private func currentUI() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            if #available(iOS 13.0, *) {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
                let orientation = activeScene?.interfaceOrientation
                
                switch orientation {
                    case .landscapeLeft:
                        return .landscapeRight
                    case .landscapeRight:
                        return .landscapeLeft
                    case .portraitUpsideDown:
                        return .portraitUpsideDown
                    case .portrait, .unknown, nil:
                        return .portrait
                    @unknown default:
                        return .portrait
                }
            } else {
                // iOS 12 and earlier
                switch UIApplication.shared.statusBarOrientation {
                    case .landscapeLeft:
                        return .landscapeRight
                    case .landscapeRight:
                        return .landscapeLeft
                    case .portraitUpsideDown:
                        return .portraitUpsideDown
                    case .portrait, .unknown:
                        return .portrait
                    @unknown default:
                        return .portrait
                }
            }
        }
        
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
}
