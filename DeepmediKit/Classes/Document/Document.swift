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
//    private let dataModel = DataModel.shared
    private let model = Model.shared
    
    // MARK: 측정데이터 파일생성
    func makeDocument(
        data type: DataModel.type,
        dataSet: [(Double, Float, Float, Float)]
    ) -> URL? {
        guard let firstTS = dataSet.first?.0 else { return nil }
        let dataSet = dataSet.map { ($0.0 - firstTS, $0.1, $0.2, $0.3) }
        let docuURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let part = model.measurePart.rawValue
        var fileURL: URL
        
        switch type {
            case .rgb:
                fileURL = docuURL.appendingPathComponent("PPG_DATA_\(part)_ios.txt")
            case .acc:
                fileURL = docuURL.appendingPathComponent("ACC_DATA_\(part)_ios.txt")
            case .gyro:
                fileURL = docuURL.appendingPathComponent("GYRO_DATA_\(part)_ios.txt")
        }
        transrateDataToTxtFile(
            fileURL,
            data: type,
            dataSet: dataSet
        )
        return fileURL
    }
    
    private func transrateDataToTxtFile(
        _ file: URL,
        data type: DataModel.type,
        dataSet: [(Double, Float, Float, Float)]
    ) {
        var data: [(Double, Float, Float, Float)] = []
        var dataToArr: [String] = [""]
        var dataSubStr: String = ""
        
        switch type {
                
            case .rgb:
                data = dataSet
            case .acc:
                data = dataSet
            case .gyro:
                data = dataSet
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
    
//    func makeDocuFromChestData() {
//        let docuURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
//        
//        let chestFilePath = docuURL.appendingPathComponent("data.bin")
//        self.dataModel.chestDataPath = chestFilePath
//        self.transrateChestDataToByteArr(chestFilePath)
//    }
//    
//    private func transrateFaceDataToTxtFile(
//        _ fileURL: URL
//    ) {
//        
//        self.dataModel.rgbData.forEach { dataMass in
//            self.dataModel.rgbDataToArr.append("\(dataMass.0 as Float64)\t" + "\(dataMass.1)\t" + "\(dataMass.2)\t" + "\(dataMass.3)\n")
//        }
//        
//        for i in self.dataModel.rgbDataToArr.indices {
//            self.dataModel.rgbSubStr += "\(self.dataModel.rgbDataToArr[i])"
//        }
//        
//        try? self.dataModel.rgbSubStr.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
//    }
//    
//    private func transrateChestDataToByteArr(
//        _ fileURL: URL
//    ) {
//        
//        var data = Data()
//        
//        let length = self.byteArray(from: 900),
//            chestSize = self.byteArray(from: 32)
//        
//        for i in length.indices {
//            if i > 3 {
//                let lengthArr = length[i]
//                self.dataModel.byteData.append(lengthArr)
//            }
//        }
//        
//        for i in chestSize.indices {
//            if i > 3 {
//                let sizeArr = chestSize[i]
//                self.dataModel.byteData.append(sizeArr)
//            }
//        }
//        
//        for i in chestSize.indices {
//            if i > 3 {
//                let sizeArr = chestSize[i]
//                self.dataModel.byteData.append(sizeArr)
//            }
//        }
//        
//        self.dataModel.timeStamp.forEach { time in
//            
//            let timeDiff = Int((time - self.dataModel.timeStamp.first!) / 1000),
//                timeToByteArr = self.byteArray(from: timeDiff)
//            
//            for i in timeToByteArr.indices {
//                if i > 3 {
//                    let timeArr = timeToByteArr[i]
//                    self.dataModel.byteData.append(timeArr)
//                }
//            }
//        }
//        
//        self.dataModel.bytesArr.forEach { byteArr in
//            byteArr.forEach { byte in
//                self.dataModel.byteData.append(byte)
//            }
//        }
//        
//        data = NSData(bytes: self.dataModel.byteData, length: self.dataModel.byteData.count) as Data
//        
//        try? data.write(to: fileURL, options: .atomic)
//    }
//    
//    private func byteArray<T>(
//        from value: T
//    ) -> [UInt8] where T: FixedWidthInteger {
//        withUnsafeBytes(of: value.bigEndian, Array.init)
//    }
}
