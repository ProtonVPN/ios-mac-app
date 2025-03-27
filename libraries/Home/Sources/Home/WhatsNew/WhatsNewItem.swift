//
//  Created on 25/02/2025.
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

@available(iOS 17.0, *)
public enum WhatsNew {
    public struct Item: Identifiable {
        public let id: String
        let rules: [Rule]
        let delayBeforeFirstPresentation: DateComponents?
        let presentationAmount: Int
        let delayBetweenPresentations: DateComponents?

        init(
            id: String,
            rules: [Rule],
            delayBeforeFirstPresentation: DateComponents? = nil,
            presentationAmount: Int = 1,
            delayBetweenPresentations: DateComponents? = nil
        ) {
            self.id = id
            self.rules = rules
            self.delayBeforeFirstPresentation = delayBeforeFirstPresentation
            self.presentationAmount = presentationAmount
            self.delayBetweenPresentations = delayBetweenPresentations
        }

        public static let widgetAdoption = Self.init(
            id: "widgetAdoption",
            rules: [.osVersion("17.0")],
            delayBeforeFirstPresentation: .init(day: 2),
            presentationAmount: 1,
            delayBetweenPresentations: nil
        )
    }

    enum Rule: Equatable {
        case timeWindow(start: Date, end: Date)
        case appVersions([String])
        case osVersion(String)
    }
}

@available(iOS 17.0, *)
extension WhatsNew.Item: Equatable {}

@available(iOS 17.0, *)
extension WhatsNew.Item: CaseIterable {
    public static var allCases: [WhatsNew.Item] {
        return [.widgetAdoption]
    }
}
