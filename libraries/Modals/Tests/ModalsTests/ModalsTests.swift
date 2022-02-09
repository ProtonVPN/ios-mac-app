import XCTest
import UIKit
@testable import Modals

final class ModalsTests: XCTestCase {
    func testUpsellViewControllerCreation() throws {
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(constants: Constants()))
    }
}

struct MockColors: ModalsColors {
    var background: UIColor = .white
    var text: UIColor = .white
    var brand: UIColor = .white
    var weakText: UIColor = .white
}

struct Constants: UpsellConstantsProtocol {
    var numberOfDevices: Int
    var numberOfServers: Int
    var numberOfCountries: Int

    init() {
        numberOfDevices = 0
        numberOfServers = 1
        numberOfCountries = 2
    }
}
