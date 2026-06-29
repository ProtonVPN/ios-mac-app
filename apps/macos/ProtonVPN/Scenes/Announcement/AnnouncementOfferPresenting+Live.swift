//
//  Created on 29/06/2026 by Max Kupetskyi.
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

import Announcement
import AppKit
import ComposableArchitecture
import Dependencies
import SwiftUI

private final class AnnouncementOfferControllerBox: @unchecked Sendable {
    weak var controller: NSViewController?
}

extension AnnouncementOfferPresenting: @retroactive DependencyKey {
    public static let liveValue: AnnouncementOfferPresenting = {
        let box = AnnouncementOfferControllerBox()
        return AnnouncementOfferPresenting(
            present: { store in
                MainActor.assumeIsolated {
                    @Dependency(\.windowService) var windowService
                    let controller = NSHostingController(rootView: AnnouncementOfferView(store: store))
                    box.controller = controller
                    windowService.presentKeyModal(viewController: controller, activatingApp: false)
                }
            },
            dismiss: {
                MainActor.assumeIsolated {
                    box.controller?.dismiss(nil)
                }
            }
        )
    }()
}
