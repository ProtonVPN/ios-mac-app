//
//  Created on 09/03/2026 by Max Kupetskyi.
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

import AppKit
import PaymentsShared

public enum LegacyUpsellFactory {
    @MainActor
    public static func upsellViewController(
        upsellModalType: UpsellModalType,
        upgradeAction: (() -> Void)?,
        continueAction: (() -> Void)?,
        showsCloseButton: Bool = false
    ) -> NSViewController {
        weak var weakViewController: NSViewController?
        let wrappedUpgradeAction: (() -> Void)? = {
            if let viewController = weakViewController {
                if let presentingViewController = viewController.presentingViewController {
                    presentingViewController.dismiss(viewController)
                } else {
                    viewController.view.window?.close()
                }
            }
            upgradeAction?()
        }

        let viewController = UpsellHostingViewController(
            modalType: upsellModalType,
            upgradeAction: wrappedUpgradeAction,
            continueAction: continueAction,
            showsCloseButton: showsCloseButton
        )
        weakViewController = viewController
        viewController.preferredContentSize = CGSize(width: Dimensions.width, height: Dimensions.height)
        return viewController
    }

    private enum Dimensions {
        static let width: CGFloat = 520
        static let height: CGFloat = 590
    }
}
