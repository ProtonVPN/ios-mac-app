//
//  Created on 10/08/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Dependencies

public struct PlanProvider {
    private var getPlan: () -> AccountPlan

    public var plan: AccountPlan { getPlan() }
}

extension PlanProvider: DependencyKey {
    public static var liveValue: PlanProvider {
        return PlanProvider(getPlan: {
            do {
                return try VpnKeychain.instance.fetchCached().accountPlan
            } catch {
                log.warning("Failed to retrieve Account Plan, defaulting to free", category: .keychain)
                return .free
            }
        })
    }

    static func constant(plan: AccountPlan) -> PlanProvider {
        PlanProvider(getPlan: { plan })
    }
}

extension DependencyValues {
    public var planProvider: PlanProvider {
        get { self[PlanProvider.self] }
        set { self[PlanProvider.self] = newValue }
    }
}
