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

/// A tab's navigation stack that waits for room before it pushes.
///
/// These pages live inside the sheet the tabs ride in, and a pushed page needs the whole sheet: the legacy detail
/// screens were drawn for a full screen. The room has to exist before the push begins, because a transition measures
/// its incoming page against the container as it stands at setup and holds it at that size for the length of the
/// animation, so a sheet raised underneath leaves the page sized for the height it has left. Asking first means one
/// settled layout, then one plain push.
public final class SheetNavigationController: UINavigationController {
    /// Makes room for a push and calls back once there is. Nil pushes straight away. The shell wires this when it
    /// takes the pages; the app only builds the stacks.
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
