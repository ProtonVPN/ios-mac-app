//
//  AnnouncementRefresher.swift
//  vpncore - Created on 2020-10-08.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

/// Class that can refresh announcements from API
public protocol AnnouncementRefresher {
    func tryRefreshing()
    func clear()
}

public protocol AnnouncementRefresherFactory {
    func makeAnnouncementRefresher() -> AnnouncementRefresher
}

public class AnnouncementRefresherImplementation: AnnouncementRefresher {
    
    public typealias Factory = CoreApiServiceFactory & AnnouncementStorageFactory
    private let factory: Factory
    
    private lazy var coreApiService: CoreApiService = factory.makeCoreApiService()
    private lazy var announcementStorage: AnnouncementStorage = factory.makeAnnouncementStorage()
    
    private var lastRefreshDate: Date?
    private var minRefreshInterval: TimeInterval
    
    public init(factory: Factory, minRefreshTime: TimeInterval = CoreAppConstants.UpdateTime.announcementRefreshTime) {
        self.factory = factory
        self.minRefreshInterval = minRefreshTime
        
        NotificationCenter.default.addObserver(self, selector: #selector(featureFlagsChanged), name: PropertiesManager.featureFlagsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: PropertiesManager.announcementsNotification, object: nil)
    }
    
    public func tryRefreshing() {
        if let lastRefresh = lastRefreshDate,
           Date().timeIntervalSince(lastRefresh) < minRefreshInterval {
            return
        }
        refresh()
    }

    @objc private func refresh() {
        coreApiService.getApiNotifications { [weak self] result in
            switch result {
            case let .success(announcementsResponse):
                self?.lastRefreshDate = Date()
                self?.announcementStorage.store(announcementsResponse.notifications)
            case let .failure(error):
                log.error("Error getting announcements", category: .api, metadata: ["error": "\(error)"])
            }
        }
    }
    
    public func clear() {
        lastRefreshDate = nil
        announcementStorage.clear()
    }
    
    @objc func featureFlagsChanged(_ notification: NSNotification) {
        guard let featureFlags = notification.object as? FeatureFlags else { return }
        if featureFlags.pollNotificationAPI {
            tryRefreshing()
        } else { // Hide announcements
            clear()
        }
    }
    
}
