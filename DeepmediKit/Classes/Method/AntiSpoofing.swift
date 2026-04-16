//
//  Method.swift
//  Alamofire
//
//  Created by 딥메디 on 12/22/25.
//

import UIKit
import MLKitVision
import MLKitFaceDetection
//실제얼굴인지 확인하는 클래스
final class Antispoofing: NSObject {
    private var checkLeftArr: [Bool] = [],
                checkRightArr: [Bool] = [],
                diffLeftArr: [CGFloat] = [],
                diffRightArr: [CGFloat] = []
    
    func initialize() {
        checkLeftArr.removeAll()
        checkRightArr.removeAll()
        diffLeftArr.removeAll()
        diffRightArr.removeAll()
    }
    //ML Kit에서 제공하는 프레임워크로 확인
    func checkReal(
        _ face: Face
    ) -> (left: Bool, right: Bool) {
        let leftEyeOpen  = face.leftEyeOpenProbability
        let rightEyeOpen = face.rightEyeOpenProbability
        guard leftEyeOpen != 1.0 && rightEyeOpen != 1.0 else {
            initialize()
            return (false, false)
        }
        
        let checkLeft  = leftEyeOpen < 0.3
        let checkRight = rightEyeOpen < 0.3
        
        if checkRightArr.count <= 450 {
            checkRightArr.append(checkRight)
        } else {
            checkRightArr.removeFirst()
            checkRightArr.append(checkRight)
        }
        
        if checkLeftArr.count <= 450 {
            checkLeftArr.append(checkLeft)
        } else {
            checkLeftArr.removeFirst()
            checkLeftArr.append(checkLeft)
        }
        return (
            left: containsPatternTwice(in: checkLeftArr),
            right: containsPatternTwice(in: checkRightArr)
        )
    }
    //눈 깜박임 플래그를 수집하여 연속 두번 깜박(true)일 경우 true 반환
    private func containsPatternTwice(in array: [Bool]) -> Bool {
        var count = 0
        // 배열을 반복해서 false, true 패턴을 찾습니다.
        for i in 0..<array.count - 1 {
            if array[i] == false && array[i + 1] == true {
                count += 1
            }
            // 패턴이 2개 이상 포함되었는지 체크
            if count >= 2 {
                return true
            }
        }
        return false // 패턴이 2개 이상 없으면 false 반환
    }
}
