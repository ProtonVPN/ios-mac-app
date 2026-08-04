//
//  Created on 30/07/2026.
//
//  Copyright (c) 2026 Proton AG
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

import UIKit

/// A tab's navigation stack that raises the sheet to full height before it pushes.
///
/// These pages sit inside the sheet, and pushed detail pages are designed for the whole screen. The sheet has to
/// finish rising before the push starts: UIKit measures the incoming page against the container once, at the
/// start of the transition, and keeps that size for the whole animation. Pushing first and raising the sheet
/// underneath would leave the page sized for the height the sheet used to have.
public final class SheetNavigationController: UINavigationController {
    /// Makes room for a push and calls back once there is. Nil pushes straight away. The shell wires this when it takes
    /// the pages; the app only builds the stacks.
    var makeRoomForPush: ((@escaping () -> Void) -> Void)?

    override public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard let makeRoomForPush else {
            super.pushViewController(viewController, animated: animated)
            return
        }
        makeRoomForPush { [weak self] in
            self?.pushWithRoom(viewController, animated: animated)
        }
    }

    /// The second half of a waited-for push, going straight to UIKit now that the room exists.
    private func pushWithRoom(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
    }
}
