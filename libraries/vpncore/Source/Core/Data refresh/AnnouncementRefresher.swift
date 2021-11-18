//
//  AnnouncementRefresher.swift
//  vpncore - Created on 2020-10-08.
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

/// Class that can refresh announcements from API
public protocol AnnouncementRefresher {
    func refresh()
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
    
    private var lastRefresh: Date?
    private var minRefreshTime: TimeInterval
    
    public init(factory: Factory, minRefreshTime: TimeInterval = CoreAppConstants.UpdateTime.announcementRefreshTime) {
        self.factory = factory
        self.minRefreshTime = minRefreshTime
        
        NotificationCenter.default.addObserver(self, selector: #selector(featureFlagsChanged), name: PropertiesManager.featureFlagsNotification, object: nil)
    }
    
    public func refresh() {
        if lastRefresh != nil && Date().timeIntervalSince(lastRefresh!) < minRefreshTime {
            return
        }

        coreApiService.getApiNotifications(success: { announcementsResponse in
            self.lastRefresh = Date()
            self.announcementStorage.store(announcementsResponse.notifications)
        }, failure: {error in
            log.error("Error getting announcements", category: .api, metadata: ["error": "\(error)"])
        })
    }
    
    public func clear() {
        lastRefresh = nil
        self.announcementStorage.clear()
    }
    
    @objc func featureFlagsChanged(_ notification: NSNotification) {
        guard let featureFlags = notification.object as? FeatureFlags else { return }
        if featureFlags.pollNotificationAPI {
            refresh()
        } else { // Hide announcements
            clear()
        }
    }
    
}
