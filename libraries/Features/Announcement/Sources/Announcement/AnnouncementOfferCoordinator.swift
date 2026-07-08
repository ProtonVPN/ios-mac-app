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
import Dependencies
import DependenciesMacros

@DependencyClient
public struct AnnouncementOfferPresenting: Sendable {
    public var present: @Sendable (_ store: StoreOf<AnnouncementsFeature>) -> Void
    public var dismiss: @Sendable () -> Void
}

extension AnnouncementOfferPresenting: TestDependencyKey {
    public static let testValue = AnnouncementOfferPresenting()
}

public extension DependencyValues {
    var announcementOfferPresenting: AnnouncementOfferPresenting {
        get { self[AnnouncementOfferPresenting.self] }
        set { self[AnnouncementOfferPresenting.self] = newValue }
    }
}

public struct AnnouncementOfferCoordinator {
    @Dependency(\.announcementManager) private var announcementManager
    @Dependency(\.announcementOfferPresenting) private var presenter

    public init() {}

    /// Presents the current offer announcement (bell tap)
    public func presentCurrentAnnouncement() {
        present(announcementManager.currentOfferAnnouncement)
    }

    /// Presents the one-time announcement right after launch if one is pending
    public func presentOneTimeAnnouncementIfNeeded() {
        present(announcementManager.oneTimeAnnouncementToPresent())
    }

    private func present(_ announcement: Announcement?) {
        guard let announcement,
              let state = AnnouncementsFeature.State(announcement: announcement) else {
            return
        }
        announcementManager.markAsRead(announcement: announcement)

        let presenter = presenter
        let store = Store(initialState: state) {
            AnnouncementsFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { presenter.dismiss() }
        }
        presenter.present(store)
    }
}
