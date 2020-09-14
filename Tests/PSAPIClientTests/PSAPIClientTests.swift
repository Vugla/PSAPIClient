import XCTest
@testable import PSAPIClient

final class PSAPIClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(PSAPIClient().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
