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
import Modals

public struct PlansClient {
    var retrievePlans: () async throws -> [PlanOption]
    var validate: @MainActor (PlanOption) async -> Void
    var notNow: () -> Void
    public init(retrievePlans: @escaping () async throws -> [PlanOption],
                validate: @MainActor @escaping (PlanOption) async -> Void = { _ in },
                notNow: @escaping () -> Void = {}
    ) {
        self.retrievePlans = retrievePlans
        self.validate = validate
        self.notNow = notNow
    }
}

final class PlanOptionsListViewModel: ObservableObject {
    @Published private(set) var plans: [PlanOption] = []
    @Published var selectedPlan: PlanOption?

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isPurchaseInProgress: Bool = false // TODO: VPNAPPL-2089 Block the UI until the purchase is complete or cancelled

    private let client: PlansClient

    var mostExpensivePlan: PlanOption?

    init(client: PlansClient) {
        self.client = client
    }

    @MainActor
    func onAppear() async {
        isLoading = true
        do {
            plans = try await client.retrievePlans()
            selectedPlan = plans.first
            mostExpensivePlan = plans.sorted { $0.pricePerMonth > $1.pricePerMonth }.first
            isLoading = false
        } catch {
            // TODO: VPNAPPL-2089 handle failed attempt to `retrievePlans`. Log the error message
            client.notNow()
        }
    }

    func validate() async {
        guard let selectedPlan else { return }
        isPurchaseInProgress = true
        await client.validate(selectedPlan)
        isPurchaseInProgress = false
    }

    func notNow() {
        client.notNow()
    }
}
