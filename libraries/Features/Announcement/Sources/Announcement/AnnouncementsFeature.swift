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

import ComposableArchitecture
import Domain
import Foundation
import VPNAppCore

@Reducer
public struct AnnouncementsFeature {
    @Dependency(\.dismiss) private var dismiss

    @ObservableState
    public struct State: Equatable {
        public let panel: OfferPanel
        public let offerReference: String?

        public init(panel: OfferPanel, offerReference: String?) {
            self.panel = panel
            self.offerReference = offerReference
        }

        /// Builds the modal state from an announcement, or `nil` when it carries no offer panel.
        public init?(announcement: Announcement) {
            guard let panel = announcement.offer?.panel else { return nil }
            self.init(panel: panel, offerReference: announcement.reference)
        }
    }

    public enum Action {
        case onAppear
        case actionButtonTapped
        case closeButtonTapped
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { [reference = state.offerReference] _ in
                    AppEvent.userWasDisplayedAnnouncement.post(reference)
                }

            case .actionButtonTapped:
                let button = state.panel.button
                guard button.action == .openURL else {
                    log.warning(
                        "Announcement button action is not <OpenURL>: \(String(describing: button.action))",
                        category: .app
                    )
                    return .run { [dismiss] _ in await dismiss() }
                }
                return .run { [dismiss, button, reference = state.offerReference] _ in
                    AppEvent.userEngagedWithAnnouncement.post(reference)
                    @Dependency(\.linkOpener) var linkOpener
                    if button.behaviors?.contains(.autoLogin) == true {
                        @Dependency(\.sessionService) var sessionService
                        let url = await sessionService.getUpgradePlanSession(url: button.url)
                        await MainActor.run { linkOpener.open(url) }
                    } else {
                        await MainActor.run { linkOpener.open(button.url) }
                    }
                    await dismiss()
                }

            case .closeButtonTapped:
                return .run { [dismiss] _ in await dismiss() }
            }
        }
    }
}
