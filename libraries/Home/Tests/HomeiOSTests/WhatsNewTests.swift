//
//  Created on 10/03/2025.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Testing

@testable import Home
@testable import Home_iOS
import ComposableArchitecture

// MARK: - Definitions

extension WhatsNew.Item {
    static let testingNoRuleItem: Self = .init(
        id: "testingNoRuleItem",
        rules: [],
        presentationAmount: 0,
        delayBetweenPresentations: nil
    )

    static let testingOneRuleItem: Self = .init(
        id: "testingOneRuleItem",
        rules: [.appVersions(["6.0.0"])],
        presentationAmount: 1,
        delayBetweenPresentations: nil
    )

    static let testingMultiRulesItem: Self = .init(
        id: "testingMultiRulesItem",
        rules: [
            .appVersions(["6.1.0", "6.0.0"]),
            .osVersion("18.4"),
            .timeWindow(start: .januaryFirst2025, end: .julyFirst2025)
        ],
        presentationAmount: 1,
        delayBetweenPresentations: nil
    )

    static let testingDelayItem: Self = .init(
        id: "testingDelayItem",
        rules: [
            .appVersions(["6.0.0"])
        ],
        delayBeforeFirstPresentation: .init(day: 2),
        presentationAmount: 3,
        delayBetweenPresentations: .init(day: 7)
    )

    static let testingWeirdItem: Self = .init(
        id: "testingWeirdItem",
        rules: [
            .appVersions(["6.0.99"])
        ],
        presentationAmount: 0,
        delayBetweenPresentations: nil
    )

    static let testingWeirdItem2: Self = .init(
        id: "testingWeirdItem2",
        rules: [
            .appVersions(["6.0.0"]),
            .osVersion("19.0")
        ],
        presentationAmount: 0,
        delayBetweenPresentations: nil
    )
}

// MARK: - Tests

typealias Evaluator = WhatsNew.Evaluator

@Test
func evaluatingItemsRules() {
    let noDataBeforeClient = WhatsNewEvaluatorClient {
        "6.0.0"
    } systemOSVersion: {
        "18.4.0"
    } itemPresentationData: { item in
        nil
    }

    withDependencies {
        $0.evaluatorClient = noDataBeforeClient
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingNoRuleItem]) == [.testingNoRuleItem])
        #expect(Evaluator.evaluate(items: [.testingNoRuleItem, .testingOneRuleItem]) == [.testingNoRuleItem, .testingOneRuleItem])
        #expect(Evaluator.evaluate(items: [.testingNoRuleItem, .testingWeirdItem]) == [.testingNoRuleItem])
        #expect(Evaluator.evaluate(items: [.testingWeirdItem]) == [])
        #expect(Evaluator.evaluate(items: [.testingWeirdItem2]) == [])
    }

    withDependencies {
        $0.evaluatorClient = noDataBeforeClient
        $0.date.now = .aprilFirst2025
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingMultiRulesItem]) == [.testingMultiRulesItem])
    }

    withDependencies {
        $0.evaluatorClient = noDataBeforeClient
        $0.date.now = .decemberFirst2025
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingMultiRulesItem]) == [])
    }
}

@Test
func presentationRules() {
    // No Data before
    var basicEvaluatorClient = WhatsNewEvaluatorClient {
        "6.0.0"
    } systemOSVersion: {
        "18.4.0"
    } itemPresentationData: { item in
        nil
    }

    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingOneRuleItem]) == [.testingOneRuleItem])
    }

    // Presented once so should not be presented anymore
    basicEvaluatorClient.itemPresentationData = { item in
        guard item == .testingOneRuleItem else {
            return nil
        }
        return WhatsNew.PresentationDataItem(amount: 1, firstRegistrationDate: .now)
    }

    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingOneRuleItem]) == [])
    }

    // Not presented yet but registered not long ago
    basicEvaluatorClient.itemPresentationData = { item in
        guard item == .testingDelayItem else {
            return nil
        }
        return WhatsNew.PresentationDataItem(amount: 0, firstRegistrationDate: .aprilFirst2025)
    }

    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
        $0.date.now = Date(timeIntervalSince1970: Date.aprilFirst2025.timeIntervalSince1970 + 86400) // +1 day
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingDelayItem]) == [])
    }

    // Not presented yet but registered 3 days ago (and item requires 2 days before first presentation)
    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
        $0.date.now = Date(timeIntervalSince1970: Date.aprilFirst2025.timeIntervalSince1970 + 3 * 86400) // +3 days
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingDelayItem]) == [.testingDelayItem])
    }

    // Presented once but less than 7 days
    basicEvaluatorClient.itemPresentationData = { item in
        guard item == .testingDelayItem else {
            return nil
        }
        return WhatsNew.PresentationDataItem(amount: 1, firstRegistrationDate: .aprilFirst2025, lastPresentationDate: .aprilFirst2025)
    }

    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
        $0.date.now = .aprilFirst2025
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingDelayItem]) == [])
    }

    // Presented once but more than 7 days
    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
        $0.date.now = Date(timeIntervalSince1970: Date.aprilFirst2025.timeIntervalSince1970 + (604_800 * 2)) // +2 weeks
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingDelayItem]) == [.testingDelayItem])
    }

    // Already presented 3 times
    basicEvaluatorClient.itemPresentationData = { item in
        guard item == .testingDelayItem else {
            return nil
        }
        return WhatsNew.PresentationDataItem(amount: 3, firstRegistrationDate: .now, lastPresentationDate: .aprilFirst2025)
    }
    withDependencies {
        $0.evaluatorClient = basicEvaluatorClient
        $0.date.now = Date(timeIntervalSince1970: Date.aprilFirst2025.timeIntervalSince1970 + (604_800 * 2)) // +2 weeks
    } operation: {
        #expect(Evaluator.evaluate(items: [.testingDelayItem]) == [])
    }
}

// MARK: - Helpers

private extension Date {
    static var januaryFirst2025: Date {
        .init(timeIntervalSince1970: 1_735_686_001)
    }

    static var aprilFirst2025: Date {
        .init(timeIntervalSince1970: 1_743_458_400)
    }

    static var julyFirst2025: Date {
        .init(timeIntervalSince1970: 1_751_320_801)
    }

    static var decemberFirst2025: Date {
        .init(timeIntervalSince1970: 1_764_543_600)
    }
}
