//
//  Created on 28/02/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Combine
import Dependencies
import Foundation
import ModalsServices
import ModalsShared

public struct PlansClient {
    var retrievePlans: () async throws -> [PlanOption]
    var validate: (PlanOption) async -> Void
    var availableDiscount: (PlanOption) -> Int?
    var notNow: (Error?) -> Void

    public init(
        retrievePlans: @escaping () async throws -> [PlanOption],
        validate: @escaping (PlanOption) async -> Void,
        availableDiscount: @escaping (PlanOption) -> Int?,
        notNow: @escaping (Error?) -> Void
    ) {
        self.retrievePlans = retrievePlans
        self.validate = validate
        self.availableDiscount = availableDiscount
        self.notNow = notNow
    }
}

// TODO: Migrate to @MainActor once overall codebase is ready for it

final class PlanOptionsListViewModel: ObservableObject {
    let client: PlansClient

    @Published private(set) var plans: [PlanOption] = []
    @Published var selectedPlan: PlanOption?

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

    init(client: PlansClient) {
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
    func availableDiscount(comparedTo plan: PlanOption) -> Int? {
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
        dateFormatter.dateFormat = "dd MMM YYYY"
        return dateFormatter
    }
}

#if DEBUG
    public extension PlansClient {
        static func mock() -> PlansClient {
            PlansClient(
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
