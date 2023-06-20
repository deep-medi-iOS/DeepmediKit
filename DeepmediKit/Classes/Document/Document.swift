//
//  Document.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//
import Foundation
import UIKit

public class Document {
    private let fileManager = FileManager()
    private let dataModel = DataModel.shared
    private let model = Model.shared
    
    // MARK: 측정데이터 파일생성
    func makeDocument(
        data type: DataModel.type
    ) {
        let docuURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let part = model.measurePart.rawValue
        var fileURL: URL
        
        switch type {
            
        case .rgb:
            fileURL = docuURL.appendingPathComponent("PPG_DATA_\(part)_ios.txt")
            self.dataModel.rgbDataPath = fileURL
        case .acc:
            fileURL = docuURL.appendingPathComponent("ACC_DATA_\(part)_ios.txt")
            self.dataModel.accDataPath = fileURL
        case .gyro:
            fileURL = docuURL.appendingPathComponent("GYRO_DATA_\(part)_ios.txt")
            self.dataModel.gyroDataPath = fileURL
        }
        
        self.transrateDataToTxtFile(fileURL, data: type)
    }
    
    func makeDocuFromChestData() {
        let docuURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let chestFilePath = docuURL.appendingPathComponent("data.bin")
        self.dataModel.chestDataPath = chestFilePath
        self.transrateChestDataToByteArr(chestFilePath)
    }
    
    private func transrateFaceDataToTxtFile(
        _ fileURL: URL
    ) {
        
        self.dataModel.rgbData.forEach { dataMass in
            self.dataModel.rgbDataToArr.append("\(dataMass.0 as Float64)\t" + "\(dataMass.1)\t" + "\(dataMass.2)\t" + "\(dataMass.3)\n")
        }
        
        for i in self.dataModel.rgbDataToArr.indices {
            self.dataModel.rgbSubStr += "\(self.dataModel.rgbDataToArr[i])"
        }
        
        try? self.dataModel.rgbSubStr.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
    }
    
    private func transrateChestDataToByteArr(
        _ fileURL: URL
    ) {
        
        var data = Data()
        
        let length = self.byteArray(from: 900),
            chestSize = self.byteArray(from: 32)
        
        for i in length.indices {
            if i > 3 {
                let lengthArr = length[i]
                self.dataModel.byteData.append(lengthArr)
            }
        }
        
        for i in chestSize.indices {
            if i > 3 {
                let sizeArr = chestSize[i]
                self.dataModel.byteData.append(sizeArr)
            }
        }
        
        for i in chestSize.indices {
            if i > 3 {
                let sizeArr = chestSize[i]
                self.dataModel.byteData.append(sizeArr)
            }
        }
        
        self.dataModel.timeStamp.forEach { time in
            
            let timeDiff = Int((time - self.dataModel.timeStamp.first!) / 1000),
                timeToByteArr = self.byteArray(from: timeDiff)
            
            for i in timeToByteArr.indices {
                if i > 3 {
                    let timeArr = timeToByteArr[i]
                    self.dataModel.byteData.append(timeArr)
                }
            }
        }
        
        self.dataModel.bytesArr.forEach { byteArr in
            byteArr.forEach { byte in
                self.dataModel.byteData.append(byte)
            }
        }
        
        data = NSData(bytes: self.dataModel.byteData, length: self.dataModel.byteData.count) as Data
        
        try? data.write(to: fileURL, options: .atomic)
    }
    
    private func byteArray<T>(
        from value: T
    ) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }
    
    private func transrateDataToTxtFile(
        _ file: URL,
        data type: DataModel.type
    ) {
        var data: [(Double, Float, Float, Float)],
            dataToArr: [String],
            dataSubStr: String
        
        switch type {
            
        case .rgb:
            data = self.dataModel.rgbData
            dataToArr = self.dataModel.rgbDataToArr
            dataSubStr = self.dataModel.rgbSubStr
            
        case .acc:
            data = self.dataModel.accData
            dataToArr = self.dataModel.accDataToArr
            dataSubStr = self.dataModel.accSubStr
            
        case .gyro:
            data = self.dataModel.gyroData
            dataToArr = self.dataModel.gyroDataToArr
            dataSubStr = self.dataModel.gyroSubStr
        }
        
        data.forEach { dataMass in
            dataToArr.append(
                "\(dataMass.0 as Float64)\t"
                + "\(dataMass.1)\t"
                + "\(dataMass.2)\t"
                + "\(dataMass.3)\n"
            )
        }
        
        for i in dataToArr.indices {
            dataSubStr += "\(dataToArr[i])"
        }
        
        try? dataSubStr.write(to: file, atomically: true, encoding: String.Encoding.utf8)
    }
}
