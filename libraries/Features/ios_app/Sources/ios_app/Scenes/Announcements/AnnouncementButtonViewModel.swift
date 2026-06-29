//
//  AnnouncementButtonViewModel.swift
//  ProtonVPN - Created on 2020-10-21.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Announcement
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Sharing

final class AnnouncementButtonViewModel {
    // Must be pre-set in AppDelegate!
    static var shared: AnnouncementButtonViewModel!

    @Dependency(\.announcementManager) var announcementManager

    init() {
        Task { @MainActor in
            AnnouncementOfferCoordinator().presentOneTimeAnnouncementIfNeeded()
        }
    }

    // MARK: Main part

    var iconUrl: URL? {
        if let icon = announcementManager.currentOfferAnnouncement?.offer?.icon, let url = URL(string: icon) {
            return url
        }
        return nil
    }

    var showAnnouncements: Bool {
        @Shared(.featureFlags) var featureFlags
        guard featureFlags.pollNotificationAPI else {
            return false
        }
        return announcementManager.shouldShowAnnouncementsIcon()
    }

    var hasUnreadAnnouncements: Bool {
        announcementManager.hasUnreadAnnouncements
    }

    /// Bell tap: present the current announcement offer.
    func showAnnouncement() {
        AnnouncementOfferCoordinator().presentCurrentAnnouncement()
    }

    func prefetchImages() async {
        let urls = announcementManager.offerImagePrefetchURLs()
        guard !urls.isEmpty else {
            log.debug("No URLs to prefetch")
            return
        }
        log.debug("Prefetching urls: \(urls)")
        @Dependency(\.imagePrefetcher) var imagePrefetcher
        await imagePrefetcher.prefetchURLs(urls)
    }
}
