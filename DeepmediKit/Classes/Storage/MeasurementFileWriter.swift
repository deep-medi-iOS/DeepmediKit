//
//  MeasurementFileWriter.swift
//  DeepmediKit
//
//  Created by 딥메디 on 2023/06/19.
//
import Foundation
import UIKit

internal final class MeasurementFileWriter {
    private let fileManager = FileManager()
    private let model = ConfigurationStore.shared
    
    enum FileDataType {
        case rgb
        case acc
        case gyro
    }
    
    private var byteData: [UInt8] = []
    
    // MARK: 측정데이터 파일생성
    func make(
        data type: FileDataType,
        dataSet: [(Double, Float, Float, Float)]
    ) -> URL? {
        guard let firstTS = dataSet.first?.0 else { return nil }
        let dataSet = dataSet.map { ($0.0 - firstTS, $0.1, $0.2, $0.3) }
        let docuURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let part = model.measurePart.rawValue
        var fileURL: URL
        
        switch type {
            case .rgb:
                fileURL = docuURL.appendingPathComponent("rgb_signal_\(part)_ios.txt")
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
        data type: FileDataType,
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
    
    func makeBin(
        dataSet: [(Double, Float, Float, Float)],
        bytesArr: [[UInt8]]
    ) -> URL? {
        let docuURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dataURL = docuURL.appendingPathComponent("data.bin")
        self.transrateDataToByteArr(dataURL, dataSet: dataSet, bytesArr: bytesArr)
        return dataURL
    }

    func makeFaceBin(
        frames bytesArr: [[UInt8]],
        timestampsUS: [UInt64]
    ) -> URL? {
        guard !bytesArr.isEmpty,
              bytesArr.count == timestampsUS.count,
              bytesArr.allSatisfy({ $0.count == 36 * 36 * 3 }) else {
            return nil
        }

        let docuURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docuURL.appendingPathComponent("face.bin")

        var frames = [SampleBufferConverter.FaceBinFrame]()
        frames.reserveCapacity(bytesArr.count)
        for i in 0..<bytesArr.count {
            frames.append(
                .init(rgb36x36: bytesArr[i], timestampUS: timestampsUS[i])
            )
        }

        do {
            try SampleBufferConverter.writeFaceBin(frames, to: fileURL)
            return fileURL
        } catch {
            assertionFailure("face.bin 저장 실패: \(error)")
            return nil
        }
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
