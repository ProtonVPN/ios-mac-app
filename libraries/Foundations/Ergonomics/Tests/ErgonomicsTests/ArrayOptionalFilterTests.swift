@testable import Ergonomics
import XCTest

final class ArrayOptionalFilterTests: XCTestCase {
    func testFilterAcceptsNilClosureAndReturnsTheSameArray() throws {
        let array = [1, 2, 3, 4, 5]
        XCTAssertEqual(array, array.filter(nil))
    }
}
