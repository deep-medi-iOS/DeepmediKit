//
//  Service.swift
//
//  Created by 딥메디 on 2/27/24.
//

import Foundation
import UIKit

/// 앱에서 실제 사용 중인 DeepmediKit SDK 버전을 제공한다.
public enum DeepmediKitSDK {
    // 번들 메타데이터를 읽을 수 없는 정적 링크 환경에서 사용할 버전이다.
    private static let fallbackVersion = "3.6.3"

    /// 리소스 번들과 프레임워크에서 현재 로드된 SDK 버전을 찾는다.
    public static let version: String = {
        var candidates = [Bundle]()

        // CocoaPods가 생성한 DeepmediKit 리소스 번들을 우선 확인한다.
        if let resourceBundleURL = Bundle.main.url(
            forResource: "DeepmediKit",
            withExtension: "bundle"
        ),
           let resourceBundle = Bundle(url: resourceBundleURL) {
            candidates.append(resourceBundle)
        }

        candidates.append(Bundle(for: DeepmediKitSDKBundleToken.self))
        candidates.append(contentsOf: Bundle.allFrameworks)

        for bundle in candidates where isDeepmediKitBundle(bundle) {
            if let version = bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String,
               !version.isEmpty {
                return version
            }
        }

        return fallbackVersion
    }()

    private static func isDeepmediKitBundle(_ bundle: Bundle) -> Bool {
        if bundle.bundleIdentifier == "org.cocoapods.DeepmediKit" {
            return true
        }

        return bundle.bundleURL
            .deletingPathExtension()
            .lastPathComponent == "DeepmediKit"
    }
}

private final class DeepmediKitSDKBundleToken {}

public enum GenderType: Int, Codable {
    case male = 0
    case female = 1
}

public enum DeepmediServiceError: Error {
    case invalidURL(String)
    case invalidResponse
    case statusCode(Int, String)
    case apiResult(Int, String)
}

extension DeepmediServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response"
        case .statusCode(let code, let body):
            return "status code error: \(code), body: \(body)"
        case .apiResult(let result, let message):
            return "api result error: \(result), message: \(message)"
        }
    }
}

public enum FailureDiagnosticFailedAPI: String, CaseIterable {
    case extractBPFeatureCalibration = "extract-bp-ft(calib)"
    case extractBPFeatureTarget = "extract-bp-ft(target)"
    case estimateStressFromRR = "estimate-stress-from-rr"
    case estimateSingleBPVital = "estimate-single-bp-vital"
    case estimateFromRawPPGPredict = "estimate-from-raw-ppg-predit"
}

public struct FailureDiagnosticDebugInfo {
    public let failedApi: String
    public let exceptionType: String
    public let httpCode: Int?
    public let apiResult: Int?
    public let message: String
    /// 오류가 발생한 앱에서 사용 중이던 SDK 버전이다.
    public let sdkVersion: String
    public let device: String
    public let osApiLevel: String
    public let occurredAt: String
    public let errorBody: String

    public init(
        failedApi: FailureDiagnosticFailedAPI,
        exceptionType: String,
        httpCode: Int?,
        apiResult: Int?,
        message: String,
        sdkVersion: String = DeepmediKitSDK.version,
        device: String = FailureDiagnosticDebugInfo.currentDeviceModel(),
        osApiLevel: String = UIDevice.current.systemVersion,
        occurredAt: Date = Date(),
        errorBody: String?
    ) {
        self.init(
            failedApi: failedApi.rawValue,
            exceptionType: exceptionType,
            httpCode: httpCode,
            apiResult: apiResult,
            message: message,
            sdkVersion: sdkVersion,
            device: device,
            osApiLevel: osApiLevel,
            occurredAt: occurredAt,
            errorBody: errorBody
        )
    }

    public init(
        failedApi: String,
        exceptionType: String,
        httpCode: Int?,
        apiResult: Int?,
        message: String,
        sdkVersion: String = DeepmediKitSDK.version,
        device: String = FailureDiagnosticDebugInfo.currentDeviceModel(),
        osApiLevel: String = UIDevice.current.systemVersion,
        occurredAt: Date = Date(),
        errorBody: String?
    ) {
        self.failedApi = failedApi
        self.exceptionType = exceptionType
        self.httpCode = httpCode
        self.apiResult = apiResult
        self.message = message
        self.sdkVersion = sdkVersion
        self.device = device
        self.osApiLevel = osApiLevel
        self.occurredAt = Self.timestampString(from: occurredAt)
        self.errorBody = Self.normalizedErrorBody(errorBody)
    }

    public init(
        failedApi: FailureDiagnosticFailedAPI,
        error: Error,
        occurredAt: Date = Date(),
        errorBody: String? = nil
    ) {
        self.init(
            failedApi: failedApi.rawValue,
            error: error,
            occurredAt: occurredAt,
            errorBody: errorBody
        )
    }

    public init(
        failedApi: String,
        error: Error,
        occurredAt: Date = Date(),
        errorBody: String? = nil
    ) {
        let fields = Self.failureFields(from: error, errorBodyOverride: errorBody)
        self.init(
            failedApi: failedApi,
            exceptionType: fields.exceptionType,
            httpCode: fields.httpCode,
            apiResult: fields.apiResult,
            message: fields.message,
            occurredAt: occurredAt,
            errorBody: fields.errorBody
        )
    }

    public static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    public static func currentDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        } ?? UIDevice.current.model

        return "\(UIDevice.current.model) (\(identifier))"
    }

    private static func failureFields(
        from error: Error,
        errorBodyOverride: String?
    ) -> FailureDiagnosticErrorFields {
        if let serviceError = error as? DeepmediServiceError {
            switch serviceError {
            case .invalidURL:
                return FailureDiagnosticErrorFields(
                    exceptionType: "InvalidURL",
                    httpCode: nil,
                    apiResult: nil,
                    message: serviceError.localizedDescription,
                    errorBody: normalizedErrorBody(errorBodyOverride)
                )

            case .invalidResponse:
                return FailureDiagnosticErrorFields(
                    exceptionType: "InvalidResponse",
                    httpCode: nil,
                    apiResult: nil,
                    message: serviceError.localizedDescription,
                    errorBody: normalizedErrorBody(errorBodyOverride)
                )

            case .statusCode(let code, let body):
                return FailureDiagnosticErrorFields(
                    exceptionType: "HTTPStatusCodeError",
                    httpCode: code,
                    apiResult: nil,
                    message: serviceError.localizedDescription,
                    errorBody: normalizedErrorBody(errorBodyOverride ?? body)
                )

            case .apiResult(let result, let message):
                return FailureDiagnosticErrorFields(
                    exceptionType: "APIResultError",
                    httpCode: nil,
                    apiResult: result,
                    message: message,
                    errorBody: normalizedErrorBody(errorBodyOverride)
                )
            }
        }

        if let urlError = error as? URLError {
            return FailureDiagnosticErrorFields(
                exceptionType: "URLError",
                httpCode: nil,
                apiResult: nil,
                message: urlError.localizedDescription,
                errorBody: normalizedErrorBody(errorBodyOverride)
            )
        }

        return FailureDiagnosticErrorFields(
            exceptionType: String(describing: type(of: error)),
            httpCode: nil,
            apiResult: nil,
            message: error.localizedDescription,
            errorBody: normalizedErrorBody(errorBodyOverride)
        )
    }

    private static func normalizedErrorBody(_ body: String?) -> String {
        guard let body,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "(none)"
        }
        return body
    }
}

public struct FailureDiagnosticFileSet {
    public let bucketName: String
    public let subject: String
    public let timestamp: String
    public let binFileName: String
    public let debugFileName: String
    public let binURL: URL
    public let debugTextURL: URL
    public let binContentType: String
    public let debugTextContentType: String
}

public final class FailureDiagnosticDebugFileWriter {
    public static let bucketName = "doosan-error-report"
    public static let platformFolder = "ios"
    public static let binContentType = "application/octet-stream"
    public static let debugTextContentType = "text/plain"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func makeSubject(timestamp: String) -> String {
        "\(Self.platformFolder)/api-fail/\(timestamp)"
    }

    public func makeBinFileName(timestamp: String) -> String {
        "\(timestamp).bin"
    }

    public func makeDebugFileName(timestamp: String) -> String {
        "\(timestamp)_debug.txt"
    }

    public func makeDebugText(from info: FailureDiagnosticDebugInfo) -> String {
        // 장애 파일만으로 실행 SDK 버전을 확인할 수 있도록 함께 기록한다.
        [
            "failedApi=\(oneLine(info.failedApi))",
            "exceptionType=\(oneLine(info.exceptionType))",
            "httpCode=\(nullable(info.httpCode))",
            "apiResult=\(nullable(info.apiResult))",
            "message=\(oneLine(info.message))",
            "sdkVersion=\(oneLine(info.sdkVersion))",
            "device=\(oneLine(info.device))",
            "osApiLevel=\(oneLine(info.osApiLevel))",
            "occurredAt=\(oneLine(info.occurredAt))",
            "--- errorBody (server raw response) ---",
            info.errorBody
        ].joined(separator: "\n")
    }

    @discardableResult
    public func writeDebugText(
        _ info: FailureDiagnosticDebugInfo,
        baseDirectory: URL? = nil
    ) throws -> URL {
        let directory = try makeLocalDirectory(
            timestamp: info.occurredAt,
            baseDirectory: baseDirectory
        )
        let fileURL = directory.appendingPathComponent(
            makeDebugFileName(timestamp: info.occurredAt)
        )
        try makeDebugText(from: info).write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        return fileURL
    }

    public func makeDiagnosticFileSet(
        faceBinURL: URL,
        debugInfo: FailureDiagnosticDebugInfo,
        baseDirectory: URL? = nil
    ) throws -> FailureDiagnosticFileSet {
        let timestamp = debugInfo.occurredAt
        let directory = try makeLocalDirectory(
            timestamp: timestamp,
            baseDirectory: baseDirectory
        )

        let binFileName = makeBinFileName(timestamp: timestamp)
        let debugFileName = makeDebugFileName(timestamp: timestamp)
        let localBinURL = directory.appendingPathComponent(binFileName)
        let debugTextURL = directory.appendingPathComponent(debugFileName)

        if fileManager.fileExists(atPath: localBinURL.path) {
            try fileManager.removeItem(at: localBinURL)
        }
        try fileManager.copyItem(at: faceBinURL, to: localBinURL)

        try makeDebugText(from: debugInfo).write(
            to: debugTextURL,
            atomically: true,
            encoding: .utf8
        )

        return FailureDiagnosticFileSet(
            bucketName: Self.bucketName,
            subject: makeSubject(timestamp: timestamp),
            timestamp: timestamp,
            binFileName: binFileName,
            debugFileName: debugFileName,
            binURL: localBinURL,
            debugTextURL: debugTextURL,
            binContentType: Self.binContentType,
            debugTextContentType: Self.debugTextContentType
        )
    }

    public func removeTemporaryFiles(_ fileSet: FailureDiagnosticFileSet) {
        try? fileManager.removeItem(at: fileSet.binURL)
        try? fileManager.removeItem(at: fileSet.debugTextURL)

        let parentDirectory = fileSet.debugTextURL.deletingLastPathComponent()
        let remainingFiles = (try? fileManager.contentsOfDirectory(
            at: parentDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        if remainingFiles.isEmpty {
            try? fileManager.removeItem(at: parentDirectory)
        }
    }

    private func makeLocalDirectory(
        timestamp: String,
        baseDirectory: URL?
    ) throws -> URL {
        let directory = (baseDirectory ?? defaultBaseDirectory())
            .appendingPathComponent(timestamp, isDirectory: true)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func defaultBaseDirectory() -> URL {
        if let cachesDirectory = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first {
            return cachesDirectory.appendingPathComponent(
                "DeepmediFailureDiagnostics",
                isDirectory: true
            )
        }

        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                "DeepmediFailureDiagnostics",
                isDirectory: true
            )
    }

    private func nullable(_ value: Int?) -> String {
        value.map(String.init) ?? "null"
    }

    private func oneLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }
}

public enum FailureDiagnosticUploadError: Error {
    case invalidResponse
    case missingPresignedURL
    case presignedURLRequestFailed(statusCode: Int, body: String)
    case fileUploadFailed(statusCode: Int, body: String)
}

extension FailureDiagnosticUploadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid upload response"
        case .missingPresignedURL:
            return "Presigned URL is missing"
        case .presignedURLRequestFailed(let statusCode, let body):
            return "presigned URL request failed: \(statusCode), body: \(body)"
        case .fileUploadFailed(let statusCode, let body):
            return "failure diagnostic file upload failed: \(statusCode), body: \(body)"
        }
    }
}

public final class FailureDiagnosticNCPUploader {
    private let fileWriter: FailureDiagnosticDebugFileWriter
    private let session: URLSession
    private let presignedURLString: String
    private let maxRetryCount: Int
    private let retryDelayNanoseconds: UInt64

    public init(
        fileWriter: FailureDiagnosticDebugFileWriter = FailureDiagnosticDebugFileWriter(),
        session: URLSession = .shared,
        presignedURLString: String = "https://bg2rz9whff.apigw.ntruss.com/biosignal/v1/presigned-url",
        maxRetryCount: Int = 3,
        retryDelaySeconds: Double = 1.5
    ) {
        self.fileWriter = fileWriter
        self.session = session
        self.presignedURLString = presignedURLString
        self.maxRetryCount = max(1, maxRetryCount)
        self.retryDelayNanoseconds = UInt64(max(0, retryDelaySeconds) * 1_000_000_000)
    }

    public func uploadBestEffort(
        faceBinURL: URL,
        debugInfo: FailureDiagnosticDebugInfo,
        baseDirectory: URL? = nil
    ) {
        Task {
            do {
                try await upload(
                    faceBinURL: faceBinURL,
                    debugInfo: debugInfo,
                    presignedRequestHeaders: [
                        "x-ncp-apigw-api-key": "Y7fOpqGzPGUBCDYdAJDLaK29jwiN5d5YplsOGddD"
                    ],
                    baseDirectory: baseDirectory
                )
            } catch {
                print("[FailureDiagnosticNCPUploader] upload failed: \(error.localizedDescription)")
            }
        }
    }

    public func upload(
        faceBinURL: URL,
        debugInfo: FailureDiagnosticDebugInfo,
        presignedRequestHeaders: [String: String] = [:],
        baseDirectory: URL? = nil
    ) async throws {
        let fileSet = try fileWriter.makeDiagnosticFileSet(
            faceBinURL: faceBinURL,
            debugInfo: debugInfo,
            baseDirectory: baseDirectory
        )
        defer {
            fileWriter.removeTemporaryFiles(fileSet)
        }

        try await uploadWithRetry(
            fileURL: fileSet.binURL,
            fileName: fileSet.binFileName,
            contentType: fileSet.binContentType,
            bucketName: fileSet.bucketName,
            subject: fileSet.subject,
            presignedRequestHeaders: presignedRequestHeaders
        )

        try await uploadWithRetry(
            fileURL: fileSet.debugTextURL,
            fileName: fileSet.debugFileName,
            contentType: fileSet.debugTextContentType,
            bucketName: fileSet.bucketName,
            subject: fileSet.subject,
            presignedRequestHeaders: presignedRequestHeaders
        )
    }

    private func uploadWithRetry(
        fileURL: URL,
        fileName: String,
        contentType: String,
        bucketName: String,
        subject: String,
        presignedRequestHeaders: [String: String]
    ) async throws {
        var latestError: Error?

        for attempt in 1...maxRetryCount {
            do {
                let presignedURL = try await requestPresignedURL(
                    bucketName: bucketName,
                    subject: subject,
                    fileName: fileName,
                    headers: presignedRequestHeaders
                )
                try await uploadFile(
                    fileURL: fileURL,
                    presignedURL: presignedURL,
                    contentType: contentType
                )
                return
            } catch {
                latestError = error
                guard attempt < maxRetryCount else { break }
                try await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }

        if let latestError {
            throw latestError
        }
    }

    private func requestPresignedURL(
        bucketName: String,
        subject: String,
        fileName: String,
        headers: [String: String]
    ) async throws -> URL {
        guard let url = URL(string: presignedURLString) else {
            throw DeepmediServiceError.invalidURL(presignedURLString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = try JSONEncoder().encode(
            FailureDiagnosticPresignedURLRequest(
                bucketName: bucketName,
                subject: subject,
                file: fileName
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FailureDiagnosticUploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FailureDiagnosticUploadError.presignedURLRequestFailed(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let decoded = try JSONDecoder().decode(
            FailureDiagnosticPresignedURLResponse.self,
            from: data
        )

        guard let presignedURL = URL(string: decoded.presignedURL) else {
            throw FailureDiagnosticUploadError.missingPresignedURL
        }

        return presignedURL
    }

    private func uploadFile(
        fileURL: URL,
        presignedURL: URL,
        contentType: String
    ) async throws {
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let data = try Data(contentsOf: fileURL)
        let (responseData, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FailureDiagnosticUploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw FailureDiagnosticUploadError.fileUploadFailed(
                statusCode: httpResponse.statusCode,
                body: String(data: responseData, encoding: .utf8) ?? ""
            )
        }
    }
}

private struct FailureDiagnosticErrorFields {
    let exceptionType: String
    let httpCode: Int?
    let apiResult: Int?
    let message: String
    let errorBody: String
}

private struct FailureDiagnosticPresignedURLRequest: Encodable {
    let bucketName: String
    let subject: String
    let file: String

    private enum CodingKeys: String, CodingKey {
        case bucketName = "bucket_name"
        case subject
        case file
    }
}

private struct FailureDiagnosticPresignedURLResponse: Decodable {
    let objectKey: String?
    let presignedURL: String

    private enum CodingKeys: String, CodingKey {
        case objectKey = "object_key"
        case presignedURL = "presigned_url"
    }
}

public struct EstimateStressFromRr: Codable {
    public let physicalStress: Double

    public init(physicalStress: Double) {
        self.physicalStress = physicalStress
    }

    private enum CodingKeys: String, CodingKey {
        case physicalStress = "physicalStress_calib"
    }
}

public struct EstimateSingleBpVital: Codable {
    public let sys: Double
    public let dia: Double

    public init(
        sys: Double,
        dia: Double
    ) {
        self.sys = sys
        self.dia = dia
    }
}

public struct EstimateFromRawPPGPredictBpVital: Codable {
    public let calDbp: Double
    public let calSbp: Double
//    public let deltaDbp: Double
//    public let deltaSbp: Double
    public let dia: Double
    public let sys: Double

    public init(
        calDbp: Double,
        calSbp: Double,
//        deltaDbp: Double,
//        deltaSbp: Double,
        dia: Double,
        sys: Double,
    ) {
        self.calDbp = calDbp
        self.calSbp = calSbp
//        self.deltaDbp = deltaDbp
//        self.deltaSbp = deltaSbp
        self.dia = dia
        self.sys = sys
    }

    private enum CodingKeys: String, CodingKey {
        case calDbp = "cal_dbp"
        case calSbp = "cal_sbp"
//        case deltaDbp = "delta_dbp"
//        case deltaSbp = "delta_sbp"
        case dia = "estimated_dbp"
        case sys = "estimated_sbp"
    }
}

public struct BPFeatureExtraction: Codable {
    public let ft: [Double]

    public init(ft: [Double]) {
        self.ft = ft
    }
}

public final class EstimateStressFromRrProvider {
    private let network: DeepmediAPIClient

    public init(apiKey: String) {
        self.network = DeepmediAPIClient(apiKey: apiKey)
    }

    public func getEstimateStressFromRr(
        rrList: [Double],
        age: Int,
        gender: GenderType,
        k: Int
    ) async throws -> EstimateStressFromRr {
        let request = EstimateStressFromRrRequest(
            rrList: rrList,
            age: age,
            gender: gender,
            k: k
        )
        return try await network.post(
            urlString: "https://j3z0wvonif.apigw.ntruss.com/calculate_face/v1/estimate_stress_from_rr",
            body: request
        )
    }
}

public final class EstimateFromRawPPGPredict {
    private let network: DeepmediAPIClient

    public init(apiKey: String) {
        self.network = DeepmediAPIClient(apiKey: apiKey)
    }

    public func getEstimateFromRawPPGPredict(
        calSys: Int,
        calDia: Int,
        calPPG: [Double],
        targetPPG: [Double]
    ) async throws -> EstimateFromRawPPGPredictBpVital {
        let request = EstimateFromRawPPGPredictRequest(
            cal_sbp: calSys,
            cal_dbp: calDia,
            cal_ppg: calPPG,
            target_ppg: targetPPG,
            sampling_rate: 100
        )
        return try await network.post(
            urlString: "https://mqwdwf67ll.apigw.ntruss.com/bp_estimate_raw_ppg/v1/bp_estimate_from_raw_ppg/predict",
            body: request
        )
    }
}

//public final class EstimateSingleBpVitalProvider {
//    private let network: DeepmediAPIClient
//
//    public init(apiKey: String) {
//        self.network = DeepmediAPIClient(apiKey: apiKey)
//    }
//
//    public func getEstimateSingleBpVital(
//        cuffSys: Int,
//        cuffDia: Int,
//        calibFt: [Double],
//        targetFt: [Double]
//    ) async throws -> EstimateSingleBpVital {
//        let request = EstimateSingleBpVitalRequest(
//            cuff_sys: cuffSys,
//            cuff_dia: cuffDia,
//            calib_ft: calibFt,
//            target_ft: targetFt
//        )
//        return try await network.post(
//            urlString: "https://i40d9fg0vx.apigw.ntruss.com/bp_estimator/bp_estimate/bp_estimate/estimate_single_bp_vital",
//            body: request
//        )
//    }
//}
//        var calibrationBPFeatures: [Double] = []
//        let targetFeatures: [Double]
//        do {
//            targetFeatures = try await BPFeatureExtractionProvider(apiKey: apiKey)
//                .getBPFeatureExtraction(
//                    ppg: output.metrics.ppg,
//                    ts: output.ts
//                )
//                .ft
//        } catch let error {
//            uploadFailureDiagnostic(
//                failedApi: .extractBPFeatureTarget,
//                error: error,
//                output: output
//            )
//            print("extract bp feature target api error: \(error.localizedDescription)")
//            return
//        }
//
//        let calibFeatures: [Double]
//        if calibrationBPFeatures.isEmpty {
//            calibrationBPFeatures = targetFeatures
//            calibFeatures = targetFeatures
//        } else {
//            calibFeatures = calibrationBPFeatures
//        }
//
//        let bp: EstimateSingleBpVital
//        do {
//            bp = try await EstimateSingleBpVitalProvider(apiKey: apiKey)
//                .getEstimateSingleBpVital(
//                    cuffSys: cuffSys,
//                    cuffDia: cuffDia,
//                    calibFt: calibFeatures,
//                    targetFt: targetFeatures
//                )
//        } catch let error {
//            uploadFailureDiagnostic(
//                failedApi: .estimateSingleBPVital,
//                error: error,
//                output: output
//            )
//            print("estimate single bp vital api error: \(error.localizedDescription)")
//            return
//        }
//        print("[++\(#fileID):\(#line)]- bp: ", bp)//심혈관
//
//public final class BPFeatureExtractionProvider {
//    private let network: DeepmediAPIClient
//
//    public init(apiKey: String) {
//        self.network = DeepmediAPIClient(apiKey: apiKey)
//    }
//
//    public func getBPFeatureExtraction(
//        ppg: [Double],
//        ts: [Double]
//    ) async throws -> BPFeatureExtraction {
//        let request = BPFeatureExtractionRequest(
//            ppg: ppg,
//            timestamp: ts
//        )
//        return try await network.post(
//            urlString: "https://i40d9fg0vx.apigw.ntruss.com/bp_estimator/bp_estimate/bp_estimate/extract_bp_ft",
//            body: request
//        )
//    }
//}
//
//public typealias BPfeatureExtractionProvider = BPFeatureExtractionProvider

final class Service {
    static let manager = Service()
    let header = DeepmediHeaderProvider()

    private init() {}
}

private struct EstimateStressFromRrRequest: Encodable {
    let rrList: [Double]
    let age: Int
    let gender: GenderType
    let k: Int
}

private struct EstimateSingleBpVitalRequest: Encodable {
    let cuff_sys: Int
    let cuff_dia: Int
    let calib_ft: [Double]
    let target_ft: [Double]
}

private struct EstimateFromRawPPGPredictRequest: Encodable {
    let cal_sbp: Int
    let cal_dbp: Int
    let cal_ppg: [Double]
    let target_ppg: [Double]
    let sampling_rate: Int
}

private struct BPFeatureExtractionRequest: Encodable {
    let ppg: [Double]
    let timestamp: [Double]
}

private struct DeepmediAPIClient {
    private let apiKey: String
    private let headerProvider: DeepmediHeaderProvider
    private let session: URLSession

    init(
        apiKey: String,
        headerProvider: DeepmediHeaderProvider = DeepmediHeaderProvider(),
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.headerProvider = headerProvider
        self.session = session
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        urlString: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let url = URL(string: urlString) else {
            throw DeepmediServiceError.invalidURL(urlString)
        }

        let headers = try await headerProvider.getHeader(
            uri: signatureURI(for: url),
            apiKey: apiKey
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        headers.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestBody = try encoder.encode(body)
        request.httpBody = requestBody

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepmediServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeepmediServiceError.statusCode(httpResponse.statusCode, body)
        }

        try Self.validateAPIResult(from: data)
        return try Self.decodeResponse(ResponseBody.self, from: data)
    }

    private func signatureURI(for url: URL) -> String {
        guard let query = url.query, !query.isEmpty else {
            return url.path
        }
        return "\(url.path)?\(query)"
    }

    private static func decodeResponse<ResponseBody: Decodable>(
        _ type: ResponseBody.Type,
        from data: Data
    ) throws -> ResponseBody {
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(ResponseBody.self, from: data) {
            return direct
        }

        let envelope: DeepmediResponseEnvelope<ResponseBody>
        do {
            envelope = try decoder.decode(DeepmediResponseEnvelope<ResponseBody>.self, from: data)
        } catch {
            throw error
        }

        if let value = envelope.message ?? envelope.data ?? envelope.response {
            return value
        }

        throw DecodingError.valueNotFound(
            ResponseBody.self,
            DecodingError.Context(
                codingPath: [],
                debugDescription: "Expected response body or response envelope"
            )
        )
    }

    private static func validateAPIResult(from data: Data) throws {
        let decoder = JSONDecoder()
        guard let status = try? decoder.decode(DeepmediAPIStatus.self, from: data),
              let result = status.result,
              result != 200 else {
            return
        }

        throw DeepmediServiceError.apiResult(
            result,
            status.messageText ?? "unknown api error"
        )
    }
}

private struct DeepmediAPIStatus: Decodable {
    let result: Int?
    let messageText: String?

    private enum CodingKeys: String, CodingKey {
        case result
        case message
    }

    private enum MessageCodingKeys: String, CodingKey {
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intResult = try? container.decodeIfPresent(Int.self, forKey: .result) {
            self.result = intResult
        } else if let stringResult = try? container.decodeIfPresent(String.self, forKey: .result) {
            self.result = Int(stringResult)
        } else {
            self.result = nil
        }

        if let text = try? container.decodeIfPresent(String.self, forKey: .message) {
            self.messageText = text
        } else if let nested = try? container.nestedContainer(keyedBy: MessageCodingKeys.self, forKey: .message) {
            self.messageText = try nested.decodeIfPresent(String.self, forKey: .message)
        } else {
            self.messageText = nil
        }
    }
}

private struct DeepmediResponseEnvelope<T: Decodable>: Decodable {
    let message: T?
    let data: T?
    let response: T?

    private enum CodingKeys: String, CodingKey {
        case message
        case data
        case response
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try? container.decodeIfPresent(T.self, forKey: .message)
        self.data = try? container.decodeIfPresent(T.self, forKey: .data)
        self.response = try? container.decodeIfPresent(T.self, forKey: .response)
    }
}
