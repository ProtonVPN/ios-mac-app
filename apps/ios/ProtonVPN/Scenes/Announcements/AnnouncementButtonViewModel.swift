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

import vpncore

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
    private lazy var announcementsViewModel: AnnouncementsViewModel = factory.makeAnnouncementsViewModel()
    
    init(factory: Factory) {
        self.factory = factory
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
        return announcementManager.fetchCurrentAnnouncements().contains(where: { $0.type == .default })
    }
    
    var hasUnreadAnnouncements: Bool {
        return announcementManager.hasUnreadAnnouncements
    }

    func showAnnouncement() {
        announcementsViewModel.open()
    }

    func prefetchImages(completion: @escaping (Bool) -> Void) {
        let urls = announcementsViewModel.backgroundURLs()
        guard !urls.isEmpty else {
            log.debug("No URLs to prefetch")
            completion(true)
            return
        }
        log.debug("Prefetching urls: \(urls)")
        FullScreenImagePrefetcher(ImageCacheFactory()).prefetchImages(urls: urls, completion: completion)
    }
}
