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

import Dependencies

import ProtonCoreFeatureFlags

import VPNAppCore
import LegacyCommon

import Ergonomics
import Domain

// MARK: AnnouncementRefresherFactory
extension Container: AnnouncementRefresherFactory {
    public func makeAnnouncementRefresher() -> AnnouncementRefresher {
        AnnouncementRefresherImplementation(factory: self)
    }
}

/// Class that can refresh announcements from API
public protocol AnnouncementRefresher {
    func tryRefreshing()
    func clear()
}

public protocol AnnouncementRefresherFactory {
    func makeAnnouncementRefresher() -> AnnouncementRefresher
}

public class AnnouncementRefresherImplementation: AnnouncementRefresher {
    public static let defaultRefreshInterval: TimeInterval = .hours(3)

    public typealias Factory = AnnouncementStorageFactory
    private let factory: Factory
    
    private lazy var announcementStorage: AnnouncementStorage = factory.makeAnnouncementStorage()

    private let refreshInterval: TimeInterval

    private var lastRefreshDate: Date?

    public init(
        factory: Factory,
        refreshInterval: TimeInterval = AnnouncementRefresherImplementation.defaultRefreshInterval
    ) {
        self.factory = factory
        self.refreshInterval = refreshInterval

        AppEvent.featureFlags.subscribe(self, selector: #selector(featureFlagsChanged))
        AppEvent.urlActivationRefresh.subscribe(self, selector: #selector(refresh))
    }
    
    public func tryRefreshing() {
        if let lastRefresh = lastRefreshDate,
           Date().timeIntervalSince(lastRefresh) < Self.defaultRefreshInterval {
            return
        }
        lastRefreshDate = Date()
        refresh()
    }

    @objc private func refresh() {
        Task { [weak self] in
            do {
                @Dependency(\.announcementClient) var announcementClient

                let announcements = try await announcementClient.fetchAnnouncements()
                self?.announcementStorage.store(announcements.notifications)
            } catch {
                log.error("Error getting announcements", category: .api, metadata: ["error": "\(error)"])
            }
        }
    }

    public func clear() {
        lastRefreshDate = nil
        announcementStorage.clear()
    }
    
    @objc func featureFlagsChanged(_ notification: NSNotification) {
        guard let featureFlags = notification.object as? LegacyCommon.FeatureFlags else { return }
        if featureFlags.pollNotificationAPI {
            tryRefreshing()
        } else { // Hide announcements
            clear()
        }
    }
    
}
