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

import LegacyCommon

protocol AnnouncementButtonViewModelFactory {
    func makeAnnouncementButtonViewModel() -> AnnouncementButtonViewModel
}

extension DependencyContainer: AnnouncementButtonViewModelFactory {
    func makeAnnouncementButtonViewModel() -> AnnouncementButtonViewModel {
        return AnnouncementButtonViewModel(factory: self)
    }
}

final class AnnouncementButtonViewModel {
    
    // Must be pre-set in AppDelegate!
    static var shared: AnnouncementButtonViewModel!
    
    typealias Factory = PropertiesManagerFactory & AnnouncementManagerFactory & AnnouncementsViewModelFactory
    private let factory: Factory

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()
    // The announcementsViewModel property can't be lazy because we depend on the behaviour in its init method.
    private let announcementsViewModel: AnnouncementsViewModel
    
    init(factory: Factory) {
        self.factory = factory
        announcementsViewModel = factory.makeAnnouncementsViewModel()
    }
    
    // MARK: Main part

    var iconUrl: URL? {
        if let icon = announcementsViewModel.currentItem?.offer?.icon, let url = URL(string: icon) {
            return url
        }
        return nil
    }
    
    var showAnnouncements: Bool {
        guard propertiesManager.featureFlags.pollNotificationAPI else {
            return false
        }
        return announcementManager.shouldShowAnnouncementsIcon()
    }
    
    var hasUnreadAnnouncements: Bool {
        announcementManager.hasUnreadAnnouncements
    }

    func showAnnouncement() {
        announcementsViewModel.open()
    }

    func prefetchImages() async {
        let urls = announcementsViewModel.backgroundURLs()
        guard !urls.isEmpty else {
            log.debug("No URLs to prefetch")
            return
        }
        log.debug("Prefetching urls: \(urls)")
        await FullScreenImagePrefetcher(ImageCacheFactory()).prefetchImages(urls: urls)
    }
}
