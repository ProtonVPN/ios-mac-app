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
    public var presentNPS: @Sendable (_ store: StoreOf<NPSModalFeature>) -> Void
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
        guard let announcement else {
            return
        }
        if let state = AnnouncementsFeature.State(announcement: announcement) {
            present(state: state)
            announcementManager.markAsRead(announcement: announcement)
        } else if announcement.knownType == .nps {
            presentNPS()
            /// Note: We do not mark NPS survey as read.
            /// NPS survey needs to be presented each time the notifications response payload contains the type 4 notification.
            /// Backend is responsible for inserting the notification or not based on eligibility criteria which are fully implemented
            /// on the backend side.
            /// The notification ID that we use to mark the notification as read is not unique over time, so we would be blocking
            /// the app from showing future NPS surveys if we marked it as read.
        }
    }

    private func presentNPS() {
        let presenter = presenter
        let store = Store(initialState: .init()) {
            NPSModalFeature()
        }
        presenter.presentNPS(store)
    }

    private func present(state: AnnouncementsFeature.State) {
        let presenter = presenter
        let store = Store(initialState: state) {
            AnnouncementsFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { presenter.dismiss() }
        }
        presenter.present(store)
    }
}
