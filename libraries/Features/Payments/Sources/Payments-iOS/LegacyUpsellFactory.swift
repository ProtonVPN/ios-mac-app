//
//  Created on 06/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import PaymentsShared
import SwiftUI
import UIKit

public enum LegacyUpsellFactory {
    @MainActor
    public static func upsellViewControllerV2(
        upsellModalType: UpsellModalType,
        client: PlansClientV2,
        dismissAction: (() -> Void)? = nil
    ) -> UIViewController {
        let planOptionsViewV2 = PlanOptionsViewV2(
            viewModel: .init(client: client),
            upsellModalType: upsellModalType,
            dismissAction: dismissAction
        )
        return UIHostingController(rootView: planOptionsViewV2)
    }
}
