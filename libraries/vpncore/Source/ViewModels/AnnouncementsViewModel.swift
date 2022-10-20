//
//  AnnouncementsViewModel.swift
//  vpncore - Created on 2020-10-15.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public protocol AnnouncementsViewModelFactory {
    func makeAnnouncementsViewModel() -> AnnouncementsViewModel
}

/// Control view showing the list of announcements
public class AnnouncementsViewModel {
    
    public typealias Factory = AnnouncementManagerFactory & SafariServiceFactory & CoreAlertServiceFactory & AppInfoFactory
    private let factory: Factory
    
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()
    private lazy var safariService: SafariServiceProtocol = factory.makeSafariService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var appInfo: AppInfo = factory.makeAppInfo()
    private lazy var imageCache: ImageCacheFactory = ImageCacheFactory()
    
    // Data
    private(set) var items: [Announcement] = []

    public var currentItem: Announcement? {
        let firstUnread = items.first { $0.type == .default && $0.isRead != true }
        return firstUnread ?? items.first { $0.type == .default }
    }

    public var oneTimeAnnouncement: Announcement? {
        items.first { $0.type == .oneTime && $0.isRead != true }
    }
    
    // Callbacks
    public var refreshView: (() -> Void)?
    
    public init(factory: Factory) {
        self.factory = factory
        fillItems()
        // This type of announcement should ONLY be opened right after opening the app
        openOneTimeAnnouncement()
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: AnnouncementStorageNotifications.contentChanged, object: nil)
    }

    public func openOneTimeAnnouncement() {
        guard let announcement = oneTimeAnnouncement else {
            return
        }
        Task.init { [weak self] in
            guard await announcement.isImagePrefetched(imageCache: imageCache) else { return }
            self?.openAnnouncement(announcement: announcement)
        }
    }

    public func open() {
        guard let announcement = currentItem else {
            return
        }
        openAnnouncement(announcement: announcement)
    }

    /// Navigate to announcement screen
    private func openAnnouncement(announcement: Announcement) {
        announcementManager.markAsRead(announcement: announcement)

        guard let data = announcement.offer?.panel else {
            log.warning("Tried opening an announcement, but there was no offer panel available", category: .app)
            return
        }
        alertService.push(alert: AnnouncementOfferAlert(data: data))
    }
        
    // MARK: - Data
    
    private func fillItems() {
        items = announcementManager.fetchCurrentAnnouncementsFromStorage()
    }
    
    @objc func dataChanged() {
        fillItems()
        refreshView?()
    }

    public func backgroundURLs() -> [URL] {
        items.compactMap(\.prefetchableImage)
    }
}
