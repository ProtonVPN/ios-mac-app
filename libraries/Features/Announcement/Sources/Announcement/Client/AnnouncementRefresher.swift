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
import Sharing

import ProtonCoreFeatureFlags

import CommonNetworking
import VPNAppCore

import Domain
import Ergonomics

/// Class that can refresh announcements from API
public protocol AnnouncementRefresher {
    func tryRefreshing()
    func tryRefreshingAsync() async
    func clear()
}

public extension SharedKey where Self == AppStorageKey<Date?> {
    static var lastAnnouncementRefreshDate: Self {
        .appStorage("lastAnnouncementRefreshDate")
    }
}

public class AnnouncementRefresherImplementation: AnnouncementRefresher {
    public static let defaultRefreshInterval: TimeInterval = .hours(3)

    @Dependency(\.announcementStorage) private var announcementStorage

    private let refreshInterval: TimeInterval

    @Shared(.lastAnnouncementRefreshDate) public var lastRefreshDate

    public init(refreshInterval: TimeInterval = AnnouncementRefresherImplementation.defaultRefreshInterval) {
        self.refreshInterval = refreshInterval

        AppEvent.featureFlags.subscribe(self, selector: #selector(featureFlagsChanged))
        AppEvent.urlActivationRefresh.subscribe(self, selector: #selector(tryRefreshing))
    }

    @objc
    public func tryRefreshing() {
        if let lastRefresh = lastRefreshDate,
           Date().timeIntervalSince(lastRefresh) < refreshInterval {
            return
        }
        $lastRefreshDate.withLock {
            $0 = Date()
        }
        refresh()
    }

    public func tryRefreshingAsync() async {
        if let lastRefresh = lastRefreshDate,
           Date().timeIntervalSince(lastRefresh) < refreshInterval {
            return
        }
        $lastRefreshDate.withLock {
            $0 = Date()
        }
        await refreshAsync()
    }

    private func refresh() {
        Task {
            await refreshAsync()
        }
    }

    private func refreshAsync() async {
        do {
            @Dependency(\.announcementClient) var announcementClient

            let announcements = try await announcementClient.fetchAnnouncements()
            announcementStorage.store(announcements.notifications)
        } catch {
            log.error("Error getting announcements", category: .api, metadata: ["error": "\(error)"])
        }
    }

    public func clear() {
        $lastRefreshDate.withLock {
            $0 = nil
        }
        announcementStorage.clear()
    }

    @objc
    func featureFlagsChanged(_ notification: NSNotification) {
        guard let featureFlags = notification.object as? CommonNetworking.FeatureFlags else { return }
        if featureFlags.pollNotificationAPI {
            tryRefreshing()
        } else { // Hide announcements
            clear()
        }
    }
}
