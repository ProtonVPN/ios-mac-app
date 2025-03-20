//
//  Created on 2025-03-20 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation

import ComposableArchitecture

import Announcement
import Domain
import VPNAppCore

@Reducer
public struct AnnouncementBannerFeature {

    @ObservableState
    public enum State: Equatable {
        case noBanner
        case banner(Model)

        public struct Model: Equatable {
            public var imageURL: URL
            public var buttonURL: URL
            public var endTime: Date
//            public var showCountdown: Bool
            public var offerReference: String?
            public var announcement: Announcement

            public init?(announcement: Announcement) {
                self.announcement = announcement
                guard let buttonString = announcement.offer?.panel?.button.url,
                    let buttonURL = URL(string: buttonString),
                let imageURL = announcement.offer?.panel?.fullScreenImage?.firstURL else {
                    return nil
                }
                self.buttonURL = buttonURL
                self.imageURL = imageURL
                self.offerReference = announcement.reference
                self.endTime = announcement.endTime
            }
        }
    }

    @CasePathable
    public enum Action {
        case didTapDismiss
        case didTapBanner
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            guard case .banner(let model) = state else {
                return .none
            }
            switch action {
            case .didTapDismiss:
                @Dependency(\.announcementManager) var announcementManager
                announcementManager.markAsRead(announcement: model.announcement)
                state = .noBanner
                return .none
            case .didTapBanner:
                return .run { _ in
                    @Dependency(\.sessionService) var sessionService
                    let url = await sessionService.getUpgradePlanSession(url: model.buttonURL.absoluteString)
                    await MainActor.run {
                        SafariService().open(url: url)
                    }
                    AppEvent.userWasDisplayedAnnouncement.post(model.offerReference)
                    AppEvent.userEngagedWithAnnouncement.post(model.offerReference)
                }
            }
        }
    }
}
