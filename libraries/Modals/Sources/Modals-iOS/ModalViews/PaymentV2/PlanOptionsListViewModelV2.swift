//
//  Created on 07/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Combine
import Dependencies
import Foundation
import ModalsServices
import ModalsShared

public struct PlansClientV2 {
    var retrievePlans: () async throws -> [PlanOptionV2]
    var validate: (PlanOptionV2) async -> Void
    var availableDiscount: (PlanOptionV2) -> Int?
    var notNow: (Error?) -> Void

    public init(
        retrievePlans: @escaping () async throws -> [PlanOptionV2],
        validate: @escaping (PlanOptionV2) async -> Void,
        availableDiscount: @escaping (PlanOptionV2) -> Int?,
        notNow: @escaping (Error?) -> Void
    ) {
        self.retrievePlans = retrievePlans
        self.validate = validate
        self.availableDiscount = availableDiscount
        self.notNow = notNow
    }
}

// TODO: Migrate to @MainActor once overall codebase is ready for it https://protonag.atlassian.net/browse/VPNAPPL-3104

final class PlanOptionsListViewModelV2: ObservableObject {
    let client: PlansClientV2

    @Published private(set) var plans: [PlanOptionV2] = []
    @Published var selectedPlan: PlanOptionV2?

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isPurchaseInProgress: Bool = false

    var renewalTextForSelectedPlan: String? {
        @Dependency(\.date) var date
        @Dependency(\.calendar) var calendar
        let twoYearsFromNow = calendar.date(byAdding: .year, value: 2, to: date.now)
        guard let selectedPlan, let twoYearsFromNow else { return nil }
        let dateString = DateFormatter.renewalDateFormatter.string(from: twoYearsFromNow)
        return selectedPlan.renews(at: dateString)
    }

    init(client: PlansClientV2) {
        self.client = client
    }

    @MainActor
    func onAppear() async {
        isLoading = true
        do {
            plans = try await client.retrievePlans().sorted { $0.storePricePerMonth < $1.storePricePerMonth }
            selectedPlan = plans.first
            isLoading = false
        } catch {
            client.notNow(error)
        }
    }

    @MainActor
    func validate() async {
        guard let selectedPlan else { return }
        isPurchaseInProgress = true
        await client.validate(selectedPlan)
        isPurchaseInProgress = false
    }

    @MainActor
    func availableDiscount(comparedTo plan: PlanOptionV2) -> Int? {
        client.availableDiscount(plan)
    }

    @MainActor
    func notNow() {
        client.notNow(nil)
    }
}

private extension DateFormatter {
    static var renewalDateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .long
        return dateFormatter
    }
}

#if DEBUG
    public extension PlansClientV2 {
        static func mock() -> PlansClientV2 {
            PlansClientV2(
                retrievePlans: {
                    [.oneMonth, .oneYear]
                },
                validate: { option in
                    print("User wants to go with \(option)")
                },
                availableDiscount: { _ in
                    66
                },
                notNow: { _ in
                    print("User wants to stay with free plan")
                }
            )
        }
    }
#endif
