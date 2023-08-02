//
//  Data.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//

import UIKit
import CoreMotion

open class DataModel {
    static let shared = DataModel()
    
    enum RGB {
        case R, G, B
    }
    
    enum type {
        case rgb, acc, gyro
    }
    
    var rgbDataPath: URL? // 얼굴, 손가락 동시사용
    var chestDataPath: URL?
    var accDataPath: URL?
    var gyroDataPath: URL?
    
    var rData = [Float](),
        gData = [Float](),
        bData = [Float](),
        timeStamp = [Double]()
    var gTempData = [Float]()
    
    var rgbData = [(Double(), Float(), Float(), Float())]
    var rgbDataToArr = [String]()
    var rgbSubStr = String()
    
    var bytesArr = [[UInt8]]()
    var byteData = [UInt8]()
    
    var accXdata = [Float](),
        accYdata = [Float](),
        accZdata = [Float]()
    
    var accData = [(Double(),Float(),Float(),Float())]
    var accDataToArr = [String]()
    var accSubStr = String()
    
    var gyroXdata = [Float](),
        gyroYdata = [Float](),
        gyroZdata = [Float]()
    
    var gyroData = [(Double(),Float(),Float(),Float())]
    var gyroDataToArr = [String]()
    var gyroSubStr = String()
    
    // MARK: Data Init
    func initRGBData() {
        self.rData.removeAll()
        self.gData.removeAll()
        self.bData.removeAll()
        self.timeStamp.removeAll()
        self.gTempData.removeAll()
        
        self.rgbData.removeAll()
        self.rgbDataToArr.removeAll()
        self.rgbSubStr.removeAll()
    }
    
    func initAccData() {
        self.accXdata.removeAll()
        self.accYdata.removeAll()
        self.accZdata.removeAll()
        
        self.accData.removeAll()
        self.accDataToArr.removeAll()
        self.accSubStr.removeAll()
    }
    
    func initGyroData() {
        self.gyroXdata.removeAll()
        self.gyroYdata.removeAll()
        self.gyroZdata.removeAll()
       
        self.gyroData.removeAll()
        self.gyroDataToArr.removeAll()
        self.gyroSubStr.removeAll()
    }
    
    func collectRGB(
        timeStamp: Double,
        r: Float,
        g: Float,
        b: Float
    ) {
        let dataFormat = (timeStamp, r, g, b)
        self.rData.append(r)
        self.gData.append(g)
        self.bData.append(b)
        self.gTempData.append(g)
        self.timeStamp.append(timeStamp)
        self.rgbData.append(dataFormat)
    }
    
    func collectAccelemeterData(
        _ acc: CMAccelerometerData?,
        _ err: Error?
    ) {
        if err != nil {
            print("error")
            return
        } else {
            guard let accMeasureData = acc?.acceleration else {
                print("accelerometer measured data return")
                return
            }
            var x: Float = 0, y: Float = 0, z: Float = 0
            x = Float(accMeasureData.x)
            y = Float(accMeasureData.y)
            z = Float(accMeasureData.z)
            
            let timeStamp = (Date().timeIntervalSince1970 * 1000000).rounded()
            guard timeStamp > 100 else { return print("acc timeStamp error") }
            let dataFormat = (timeStamp, x, y, z)
            
            self.accXdata.append(x)
            self.accYdata.append(y)
            self.accZdata.append(z)
            self.accData.append(dataFormat)
        }
    }
    
    func collectGyroscopeData(
        _ gyro: CMGyroData?,
        _ err: Error?
    ) {
        
        if err != nil {
            print("error")
        } else {
            guard let gyroMeasureData = gyro?.rotationRate else {
                print("gyro measured data return")
                return
            }
            var x: Float = 0, y: Float = 0, z: Float = 0
            x = Float(gyroMeasureData.x)
            y = Float(gyroMeasureData.y)
            z = Float(gyroMeasureData.z)
            
            let timeStamp = (Date().timeIntervalSince1970 * 1000000).rounded()
            guard timeStamp != 0.0 else { return print("gyro timeStamp error") }
            let dataFormat = (timeStamp, x, y, z)
            
            self.gyroXdata.append(x)
            self.gyroYdata.append(y)
            self.gyroZdata.append(z)
            self.gyroData.append(dataFormat)
        }
    }
}
