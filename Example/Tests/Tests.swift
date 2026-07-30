import XCTest
import DeepmediKit

class Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    // 생성된 장애 디버그 텍스트에 SDK 버전이 포함되는지 확인한다.
    func testFailureDiagnosticDebugTextIncludesSDKVersion() {
        let info = FailureDiagnosticDebugInfo(
            failedApi: .estimateStressFromRR,
            exceptionType: "APIResultError",
            httpCode: nil,
            apiResult: 400,
            message: "rr_list is too short (minimum 10)",
            sdkVersion: "9.9.9-test",
            device: "Test Device",
            osApiLevel: "26.0",
            occurredAt: Date(timeIntervalSince1970: 0),
            errorBody: nil
        )

        let text = FailureDiagnosticDebugFileWriter().makeDebugText(from: info)

        XCTAssertTrue(text.contains("sdkVersion=9.9.9-test"))
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}
