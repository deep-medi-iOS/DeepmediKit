//
//  Document.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//
import Foundation
import UIKit

internal final class Document {
    private let fileManager = FileManager()
    private let model = Model.shared
    
    private var byteData: [UInt8] = []
    
    // MARK: 측정데이터 파일생성
    func make(
        data type: DataModel.type,
        dataSet: [(Double, Float, Float, Float)]
    ) -> URL? {
        guard let firstTS = dataSet.first?.0 else { return nil }
        let dataSet = dataSet.map { ($0.0 - firstTS, $0.1, $0.2, $0.3) }
        let docuURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let part = "face"
        var fileURL: URL
        
        switch type {
            case .rgb:
                fileURL = docuURL.appendingPathComponent("rgb_signal_ios.txt")
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
        
        try? dataSubStr.write(
            to: file,
            atomically: true,
            encoding: String.Encoding.utf8
        )
    }
    
    func saveSensorCSV<T>(
        fileName: String,
        data: [T],
        timestamp: KeyPath<T, Double>,
        x: KeyPath<T, Double>,
        y: KeyPath<T, Double>,
        z: KeyPath<T, Double>
    ) -> URL? {
        
        let url = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        var rows: [String] = []
        rows.append("timestamp_us,x,y,z")
        rows.reserveCapacity(data.count + 1)
        
        for item in data {
            let row = "\(item[keyPath: timestamp])," +
            "\(item[keyPath: x])," +
            "\(item[keyPath: y])," +
            "\(item[keyPath: z])"
            rows.append(row)
        }
        
        do {
            try rows.joined(separator: "\n")
                .write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("CSV save failed:", error)
            return nil
        }
    }
    
    func saveFrameCSV(
        data: [FaceKit.FrameData]
    ) -> URL? {
        
        let url = fileManager
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("frame_data.csv")
        makeFrameCSV(
            url: url,
            data
        )
        return url
    }
    
    private func makeFrameCSV(url: URL, _ data: [FaceKit.FrameData]) {
        var csv = """
        frame_index,timestamp_us,width,height,brightness,face_yaw,face_pitch,face_roll,iso,ae_state,awb_state,af_state
        """
        
        csv += "\n"
        
        data.enumerated().forEach { (i, item) in
            csv += """
            \(i),\
            \(item.timestampUS),\
            \(item.width),\
            \(item.height),\
            \(item.brightness),\
            \(item.faceYaw),\
            \(item.facePitch),\
            \(item.faceRoll),\
            \(item.iso),\
            \(item.aeState),\
            \(item.awbState),\
            \(item.afState)
            """
            csv += "\n"
        }
        
        try? csv.write(
            to: url,
            atomically: true,
            encoding: String.Encoding.utf8
        )
    }
    
    func makeBin(
        dataSet: [(Double, Float, Float, Float)],
        bytesArr: [[UInt8]]
    ) -> URL? {
        let docuURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataURL = docuURL.appendingPathComponent("data.bin")
        self.transrateDataToByteArr(dataURL, dataSet: dataSet, bytesArr: bytesArr)
        return dataURL
    }
    
    private func transrateDataToByteArr(
        _ fileURL: URL,
        dataSet: [(Double, Float, Float, Float)],
        bytesArr: [[UInt8]]
    ) {
        let ts: [Int64] = dataSet.map { Int64($0.0) }   // timestamp (8 bytes)
        let width = 36
        let height = 36
        let channels = 3
        let frameCount = 450
        let frameByteLength = width * height * channels // 36 * 36 * 3 = 3888
        
        // 1) 데이터 정합성 체크
        guard ts.count == frameCount else {
            assertionFailure("timestamp.count(\(ts.count)) != \(frameCount)")
            return
        }
        
        guard bytesArr.count == frameCount else {
            assertionFailure("bytesArr.count(\(bytesArr.count)) != \(frameCount)")
            return
        }
        
        guard bytesArr.allSatisfy({ $0.count == frameByteLength }) else {
            assertionFailure("각 프레임의 byteArr.count가 \(frameByteLength) 이어야 합니다.")
            return
        }
        
        // 2) Int64를 big-endian 8바이트로 append
        @inline(__always)
        func appendInt64(_ value: Int64) {
            var bigEndianValue = value.bigEndian
            withUnsafeBytes(of: &bigEndianValue) { buffer in
                self.byteData.append(contentsOf: buffer)
            }
        }
        
        // 3) 버퍼 초기화 및 용량 예약
        // header: width, height, channels, frameCount = 8 * 4 = 32 bytes
        // frameData: frameCount * frameByteLength
        // timestamps: frameCount * 8
        self.byteData.removeAll(keepingCapacity: true)
        self.byteData.reserveCapacity(
            32 + (frameCount * frameByteLength) + (8 * frameCount)
        )
        
        // 4) Header 영역
        appendInt64(Int64(width))
        appendInt64(Int64(height))
        appendInt64(Int64(channels))
        appendInt64(Int64(frameCount))
        
        // 5) Frame Data 영역
        for frame in bytesArr {
            self.byteData.append(contentsOf: frame)
        }
        
        // 6) Timestamp 영역
        for t in ts {
            appendInt64(t)
        }
        
        // 7) 파일 쓰기
        let data = Data(self.byteData)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("bin 파일 저장 실패: \(error)")
        }
    }
    
    private func byteArray<T>(from value: T) -> [UInt8] where T: FixedWidthInteger {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }
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
