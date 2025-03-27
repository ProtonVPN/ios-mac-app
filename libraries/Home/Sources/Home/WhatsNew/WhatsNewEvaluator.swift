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
import UIKit

import ComposableArchitecture

@available(iOS 17.0, *)
@DependencyClient
struct WhatsNewEvaluatorClient {
    var bundleShortVersionString: () -> String?
    var systemOSVersion: () -> String = { "" }
    var itemPresentationData: (_ for: WhatsNew.Item) -> WhatsNew.PresentationDataItem?
}

@available(iOS 17.0, *)
extension WhatsNew {
    /// Evaluates WhatsNew.Rule for WhatsNew.Item.
    /// Entry point is ``evalutate(items:)`` it returns items that should be presented.
    ///
    /// Let's keep it as *functional* as possible: it should only evaluate and not introduce side effects.
    enum Evaluator {
        @Dependency(\.evaluatorClient) private static var evaluatorClient
        @Dependency(\.date.now) private static var now

        /// Evaluates WhatsNew.Item.
        /// - Parameter items: the items you want to evaluate.
        /// - Returns: the items that should be presented.
        static func evaluate(items: [Item]) -> [Item] {
            return items.filter { item in
                let data = evaluatorClient.itemPresentationData(for: item)
                return item.rules.allSatisfy(isSatisfied(_:)) && shouldPresent(item: item, presentationData: data)
            }
        }

        private static func isSatisfied(_ rule: Rule) -> Bool {
            switch rule {
            case .timeWindow(let startDate, let endDate):
                return (startDate...endDate).contains(now)
            case .appVersions(let versions):
                return evaluatorClient.bundleShortVersionString().map { versions.contains($0) } ?? true
            case .osVersion(let version):
                let compareResult = evaluatorClient.systemOSVersion().compare(version, options: .numeric)
                return (compareResult == .orderedSame || compareResult == .orderedDescending)
            }
        }

        private static func shouldPresent(item: WhatsNew.Item, presentationData: WhatsNew.PresentationDataItem?) -> Bool {
            guard let presentationData else {
                return true
            }
            guard presentationData.amount < item.presentationAmount else {
                return false
            }
            // Let's check that there is no delay before first presentation
            if let fpDelayComponens = item.delayBeforeFirstPresentation {
                let firstRegistrationDate: Date = presentationData.firstRegistrationDate
                let minFirstPresentationDate = Calendar.current.date(byAdding: fpDelayComponens, to: firstRegistrationDate) ?? now
                if now < minFirstPresentationDate {
                    return false
                }
            }
            // Now let's make sure we account possible delays between presentations
            let minNextPresentationDate: Date
            if let components = item.delayBetweenPresentations, let lastPresentationDate = presentationData.lastPresentationDate {
                minNextPresentationDate = Calendar.current.date(byAdding: components, to: lastPresentationDate) ?? now
            } else {
                minNextPresentationDate = now
            }
            return now >= minNextPresentationDate
        }
    }
}

@available(iOS 17.0, *)
extension WhatsNew {
    struct PresentationData: Codable {
        static let storagePathComponent: String = "whatsnew.json"

        let items: [Item.ID: PresentationDataItem]
    }

    struct PresentationDataItem: Codable {
        let amount: Int
        let firstRegistrationDate: Date
        let lastPresentationDate: Date?

        init(amount: Int, firstRegistrationDate: Date, lastPresentationDate: Date? = nil) {
            if lastPresentationDate != nil {
                precondition(lastPresentationDate! >= firstRegistrationDate)
            }
            self.amount = amount
            self.firstRegistrationDate = firstRegistrationDate
            self.lastPresentationDate = lastPresentationDate
        }
    }
}

@available(iOS 17.0, *)
extension WhatsNewEvaluatorClient: DependencyKey {
    static let liveValue = WhatsNewEvaluatorClient {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    } systemOSVersion: {
        return UIDevice.current.systemVersion
    } itemPresentationData: { item in
        @Shared(.whatsNew) var whatsNewData
        return whatsNewData?.items[item.id]
    }

    static let testValue: WhatsNewEvaluatorClient = WhatsNewEvaluatorClient {
        return "6.0.0"
    } systemOSVersion: {
        return "18.0"
    } itemPresentationData: { item in
        let secondsInDay: TimeInterval = 24*60*60
        let yesterday = Date.now.addingTimeInterval(-secondsInDay)
        let beforeYesterday = Date.now.addingTimeInterval(-2*secondsInDay)
        return WhatsNew.PresentationDataItem(amount: 1, firstRegistrationDate: beforeYesterday, lastPresentationDate: yesterday)
    }
}

@available(iOS 17.0, *)
extension DependencyValues {
    var evaluatorClient: WhatsNewEvaluatorClient {
        get { self[WhatsNewEvaluatorClient.self] }
        set { self[WhatsNewEvaluatorClient.self] = newValue }
    }
}

@available(iOS 17.0, *)
extension SharedKey where Self == FileStorageKey<WhatsNew.PresentationData?> {
    static var whatsNew: Self {
        .fileStorage(.documentsDirectory.appending(component: WhatsNew.PresentationData.storagePathComponent))
    }
}
