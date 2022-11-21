import XCTest
@testable import LocalFeatureFlags

enum TestFeatureFlag: String, FeatureFlag {
    var category: String {
        "Test"
    }

    var feature: String {
        rawValue
    }

    case positiveFeatureFlag = "PositiveFeatureFlag"
    case negativeFeatureFlag = "NegativeFeatureFlag"
    case missingFeatureFlag = "MissingFeatureFlag"
}

final class LocalFeatureFlagsTests: XCTestCase {
    override func setUp() {
        Sync.sync = { closure in
            closure()
        }

        Sync.async = { closure in
            closure()
        }
    }

    func testFeatureFlags() {
        XCTAssertTrue(isEnabled(TestFeatureFlag.positiveFeatureFlag))
        XCTAssertFalse(isEnabled(TestFeatureFlag.negativeFeatureFlag))
        XCTAssertFalse(isEnabled(TestFeatureFlag.missingFeatureFlag))
    }

    func testOverrides() {
        setLocalFeatureFlagOverrides([
            "Test": [
                TestFeatureFlag.positiveFeatureFlag.rawValue: false,
                TestFeatureFlag.negativeFeatureFlag.rawValue: true,
            ]
        ])

        XCTAssertFalse(isEnabled(TestFeatureFlag.positiveFeatureFlag))
        XCTAssertTrue(isEnabled(TestFeatureFlag.negativeFeatureFlag))
        XCTAssertFalse(isEnabled(TestFeatureFlag.missingFeatureFlag))

        setLocalFeatureFlagOverrides([
            "Test": [
                TestFeatureFlag.positiveFeatureFlag.rawValue: false,
                TestFeatureFlag.negativeFeatureFlag.rawValue: true,
                TestFeatureFlag.missingFeatureFlag.rawValue: true,
            ]
        ])

        XCTAssertTrue(isEnabled(TestFeatureFlag.missingFeatureFlag))
    }
}
