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

/// Controll view showing the list of announcements
public class AnnouncementsViewModel {
    
    public typealias Factory = AnnouncementManagerFactory & SafariServiceFactory & CoreAlertServiceFactory & AppInfoFactory
    private let factory: Factory
    
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()
    private lazy var safariService: SafariServiceProtocol = factory.makeSafariService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var appInfo: AppInfo = factory.makeAppInfo()
    
    // Data
    private(set) var items: [Announcement] = [Announcement]()

    public var currentItem: Announcement? {
        let sorted = items.sorted(by: { (lhs, rhs) -> Bool in
            if let lhsRead = lhs.isRead {
                return !lhsRead
            }
            return false
        })

        return sorted.first
    }
    
    // Callbacks
    public var refreshView: (() -> Void)?
    
    public init(factory: Factory) {
        self.factory = factory
        fillItems()
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: AnnouncementStorageNotifications.contentChanged, object: nil)
    }
    
    /// Navigate to announcement screen
    public func open() {
        guard let announcement = currentItem else {
            return
        }

        announcementManager.markAsRead(announcement: announcement)

        if let data = announcement.offer?.panel {
            alertService.push(alert: AnnouncmentOfferAlert(data: data))
            return
        }
        
        if let url = announcement.offer?.url.urlWithAdded(utmSource: appInfo.clientId.lowercased()) {
            safariService.open(url: url)
        }
    }
        
    // MARK: - Data
    
    private func fillItems() {
        items = announcementManager.fetchCurrentAnnouncements()
    }
    
    @objc func dataChanged() {
        fillItems()
        refreshView?()
    }
}
