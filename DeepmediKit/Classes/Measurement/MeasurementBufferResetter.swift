//
//  InitData.swift
//  DeepmediKit
//
//  Created by 딥메디 on 4/15/26.
//

import Foundation

extension FaceKit {
    //초기화 데이터들
    internal func initRGBData() {
        timeStamp.removeAll()
        sigR.removeAll()
        sigB.removeAll()
        sigG.removeAll()
        tempG.removeAll()
        totalData.removeAll()
        bytesArray.removeAll()
        frameTimestampUS.removeAll()
        frames.removeAll()
        
        frameDataArr.removeAll()
        
        acc.removeAll()
        gyro.removeAll()
    }
    
    internal func timerReset() {
        finishVideoFrameStats(context: "timer reset")
        isTimerRunning = false
        dispatchTimer?.cancel()
        measurementTimer.invalidate()
        prepareTimer.invalidate()
    }
}
