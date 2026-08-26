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
import ComposableArchitecture
import Dependencies
import ModalsShared
import SwiftUI

extension AnnouncementOfferPresenting: @retroactive DependencyKey {
    public static var liveValue: AnnouncementOfferPresenting {
        @Sendable
        func present(controller: UIViewController) {
            @Dependency(\.windowService) var windowService
            windowService.present(controller)
        }
        return AnnouncementOfferPresenting(
            present: { store in
                MainActor.assumeIsolated {
                    let controller = UIHostingController(rootView: AnnouncementOfferView(store: store))
                    controller.modalPresentationStyle = .overFullScreen
                    present(controller: controller)
                }
            }, presentNPS: { store in
                MainActor.assumeIsolated {
                    let controller = UIHostingController(rootView: NPSModalView(store: store))
                    controller.modalPresentationStyle = .overFullScreen
                    present(controller: controller)
                }
            }, dismiss: {
                @Dependency(\.windowService) var windowService
                windowService.dismissModal(nil)
            }
        )
    }
}
