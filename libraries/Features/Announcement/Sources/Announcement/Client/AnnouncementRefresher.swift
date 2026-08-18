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

import Combine
import CommonNetworking
import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import Foundation
import ProtonCoreFeatureFlags
import Sharing
import VPNAppCore

@DependencyClient
public struct AnnouncementRefresher: Sendable {
    /// Refreshes if the throttle interval has elapsed since the last refresh
    public var tryRefreshing: @Sendable () -> Void
    /// Clears stored announcements and the last-refresh timestamp
    public var clear: @Sendable () -> Void
}

extension AnnouncementRefresher: DependencyKey {
    public static let liveValue: AnnouncementRefresher = {
        let implementation = AnnouncementRefresherImplementation()
        return AnnouncementRefresher(
            tryRefreshing: { implementation.tryRefreshing() },
            clear: { implementation.clear() }
        )
    }()
}

public extension DependencyValues {
    var announcementRefresher: AnnouncementRefresher {
        get { self[AnnouncementRefresher.self] }
        set { self[AnnouncementRefresher.self] = newValue }
    }
}

public extension SharedKey where Self == AppStorageKey<Date?> {
    static var lastAnnouncementRefreshDate: Self {
        .appStorage("lastAnnouncementRefreshDate")
    }
}

/// Holds the throttle state and the long-lived feature-flag / deep-link observations that drive refreshing
final class AnnouncementRefresherImplementation: @unchecked Sendable {
    static let defaultRefreshInterval: TimeInterval = .hours(3)

    private let refreshInterval: TimeInterval

    @SharedReader(.featureFlags) private var featureFlags: Domain.FeatureFlags
    private var featureFlagsObservation: AnyCancellable?

    init(refreshInterval: TimeInterval = AnnouncementRefresherImplementation.defaultRefreshInterval) {
        self.refreshInterval = refreshInterval

        self.featureFlagsObservation = $featureFlags.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] flags in self?.featureFlagsChanged(flags) }
        AppEvent.urlActivationRefresh.subscribe(self, selector: #selector(tryRefreshing))
    }

    @objc
    func tryRefreshing() {
        @Shared(.lastAnnouncementRefreshDate) var lastRefreshDate
        // a single lock
        let shouldRefresh = $lastRefreshDate.withLock { lastRefresh -> Bool in
            if let last = lastRefresh, Date().timeIntervalSince(last) < refreshInterval {
                return false
            }
            lastRefresh = Date()
            return true
        }
        guard shouldRefresh else { return }
        refresh()
    }

    private func refresh() {
        Task {
            await refreshAsync()
        }
    }

    private func refreshAsync() async {
        do {
            @Dependency(\.announcementClient) var announcementClient

            let response = try await announcementClient.fetchAnnouncements()
            store(response.notifications)
        } catch {
            log.error("Error getting announcements", category: .api, metadata: ["error": "\(error)"])
        }
    }

    /// Persists freshly fetched announcements, carrying over the read flags of any currently-stored
    /// announcements (this merge previously lived inside `AnnouncementStorage.store`).
    private func store(_ newAnnouncements: [Announcement]) {
        @Shared(.announcements) var announcements: [Announcement]?
        $announcements.withLock { stored in
            let readFlags = (stored ?? []).reduce(into: [String: Bool]()) { flags, announcement in
                flags[announcement.notificationID] = announcement.isRead
            }
            stored = newAnnouncements.map { announcement in
                var announcement = announcement
                announcement.setAsRead((readFlags[announcement.notificationID] ?? false) || announcement.wasRead)
                return announcement
            }
        }
    }

    func clear() {
        @Shared(.lastAnnouncementRefreshDate) var lastRefreshDate
        @Shared(.announcements) var announcements: [Announcement]?
        $lastRefreshDate.withLock {
            $0 = nil
        }
        $announcements.withLock { $0 = nil }
    }

    func featureFlagsChanged(_ featureFlags: Domain.FeatureFlags) {
        if featureFlags.pollNotificationAPI {
            tryRefreshing()
        } else { // Hide announcements
            clear()
        }
    }
}
