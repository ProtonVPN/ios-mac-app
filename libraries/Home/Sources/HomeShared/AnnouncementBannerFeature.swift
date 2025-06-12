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
    @SharedReader(.announcementBanner) var announcementBanner: Announcement?
    @SharedReader(.userTier) private var userTier: Int?

    @ObservableState
    public enum State: Equatable {
        case noBanner
        case banner(Model)

        public struct Model: Equatable {
            public private(set) var imageURL: URL
            public private(set) var buttonURL: URL
            public private(set) var endTime: Date
            public private(set) var showCountdown: Bool
            public private(set) var offerReference: String?
            public private(set) var notificationID: String

            public init?(announcement: Announcement) {
                guard let panel = announcement.offer?.panel,
                      let buttonURL = URL(string: panel.button.url),
                      let imageURL = panel.fullScreenImage?.firstURL else {
                    return nil
                }
                self.buttonURL = buttonURL
                self.imageURL = imageURL
                self.offerReference = announcement.reference
                self.endTime = announcement.endTime
                self.showCountdown = panel.showCountdown ?? false
                self.notificationID = announcement.notificationID
            }
        }
    }

    @CasePathable
    public enum Action {
        case onStart

        case didTapDismiss
        case didTapBanner

        case fetchCurrentOfferBannerFromStorage(Announcement?)
    }

    private enum CancelID {
        case announcementBanner
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onStart:
                return .publisher {
                    $announcementBanner.publisher
                        .map(Action.fetchCurrentOfferBannerFromStorage)
                }
                .cancellable(id: CancelID.announcementBanner)
            case let .fetchCurrentOfferBannerFromStorage(announcement):
                if userTier?.isFreeTier ?? true,
                   let announcement,
                   let model = AnnouncementBannerFeature.State.Model(announcement: announcement) {
                    state = .banner(model)
                }
                return .none
            case .didTapDismiss:
                guard case let .banner(model) = state else { return .none }

                @Dependency(\.announcementManager) var announcementManager
                announcementManager.markAsRead(notificationID: model.notificationID)
                state = .noBanner
                return .none
            case .didTapBanner:
                guard case let .banner(model) = state else { return .none }

                return .run { _ in
                    @Dependency(\.sessionService) var sessionService
                    let url = await sessionService.getUpgradePlanSession(url: model.buttonURL.absoluteString)
                    await MainActor.run {
                        @Dependency(\.linkOpener) var linkOpener
                        linkOpener.open(url)
                    }
                    AppEvent.userWasDisplayedAnnouncement.post(model.offerReference)
                    AppEvent.userEngagedWithAnnouncement.post(model.offerReference)
                }
            }
        }
    }
}
