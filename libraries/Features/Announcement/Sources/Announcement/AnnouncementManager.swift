//
//  AnnouncementManager.swift
//  vpncore - Created on 2020-10-09.
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
import Dependencies
import DependenciesMacros
import Foundation
import Sharing
import VPNAppCore

@DependencyClient
public struct AnnouncementManager: Sendable {
    /// Current (started, not-yet-ended, offer-bearing) announcements, oldest first.
    public var fetchCurrentAnnouncementsFromStorage: @Sendable () -> [Announcement] = { [] }
    /// The single active offer banner announcement, or `nil` if none / already read.
    public var fetchCurrentOfferBannerFromStorage: @Sendable () -> Announcement? = { nil }
    /// Marks the announcement with the given notification id as read.
    public var markAsRead: @Sendable (_ notificationID: String) -> Void
    /// Whether the announcement bell icon should be shown (a `.default` offer exists).
    public var shouldShowAnnouncementsIcon: @Sendable () -> Bool = { false }
    /// Whether there is an unread `.default` offer announcement.
    public var hasUnreadAnnouncements: @Sendable () -> Bool = { false }
    /// Emits whenever the stored announcements change, replaying the current value to new
    /// subscribers. The reliable source of truth for announcement UI to react to.
    public var announcementsPublisher: @Sendable () -> AnyPublisher<[Announcement], Never> = {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }
}

// MARK: - Convenience

public extension AnnouncementManager {
    /// The current offer announcement surfaced by the announcement bell (first `.default`).
    var currentOfferAnnouncement: Announcement? {
        fetchCurrentAnnouncementsFromStorage().first { $0.knownType == .default }
    }

    /// The bell icon URL for the current offer announcement, if any.
    var announcementIconURL: URL? {
        guard let icon = currentOfferAnnouncement?.offer?.icon else { return nil }
        return URL(string: icon)
    }

    /// The one-time announcement to auto-present right after launch, or `nil` if none is pending or
    /// one-time announcements are blocked.
    func oneTimeAnnouncementToPresent() -> Announcement? {
        #if DEBUG
            @SharedReader(.blockOneTimeAnnouncement) var blockOneTimeAnnouncement
            guard !blockOneTimeAnnouncement else { return nil }
        #endif
        return fetchCurrentAnnouncementsFromStorage().first { $0.knownType == .oneTime && $0.isRead == false }
    }

    /// Offer image URLs worth prefetching for the announcement bell.
    func offerImagePrefetchURLs() -> [URL] {
        fetchCurrentAnnouncementsFromStorage().compactMap(\.prefetchableImage)
    }

    func markAsRead(announcement: Announcement) {
        markAsRead(notificationID: announcement.notificationID)
    }
}

// MARK: - Live

extension AnnouncementManager: DependencyKey {
    public static let liveValue: AnnouncementManager = {
        // Read/write directly against the user-scoped key
        let key: UserScopedAppStorageKey<[Announcement]?> = .announcements

        let currentAnnouncements: @Sendable () -> [Announcement] = {
            (key.currentValue() ?? [])
                .filter { $0.startTime.isPast && $0.endTime.isFuture && $0.offer != nil }
                // sorting is needed because we only want to consider the first announcement
                .sorted { $0.startTime < $1.startTime }
        }

        return AnnouncementManager(
            fetchCurrentAnnouncementsFromStorage: { currentAnnouncements() },
            fetchCurrentOfferBannerFromStorage: {
                let offers = (key.currentValue() ?? [])
                    .filter { $0.knownType == .banner && $0.startTime.isPast && $0.endTime.isFuture && $0.offer != nil }
                    .sorted { $0.endTime < $1.endTime }
                if offers.count > 1 {
                    log.error("There should only ever be one or none welcome offer banner, having more is an error.")
                }
                // Only return the one with closest endTime, and only if it hasn't been read.
                return offers.first?.isRead == false ? offers.first : nil
            },
            markAsRead: { notificationID in
                guard var current = key.currentValue(),
                      let index = current.firstIndex(where: { $0.notificationID == notificationID }) else {
                    return
                }
                current[index].isRead = true
                key.setCurrentValue(current)
            },
            shouldShowAnnouncementsIcon: {
                currentAnnouncements().contains { $0.knownType == .default }
            },
            hasUnreadAnnouncements: {
                guard let announcement = currentAnnouncements().first(where: { $0.knownType == .default }) else {
                    return false
                }
                return !announcement.wasRead
            },
            announcementsPublisher: {
                @SharedReader(.announcements) var announcements
                return $announcements.publisher.map { $0 ?? [] }.eraseToAnyPublisher()
            }
        )
    }()
}

public extension DependencyValues {
    var announcementManager: AnnouncementManager {
        get { self[AnnouncementManager.self] }
        set { self[AnnouncementManager.self] = newValue }
    }
}

public extension Date {
    /// Check if this date represnt time in future
    var isFuture: Bool {
        // TODO: rethink this implementation
        timeIntervalSinceNow > 0
    }

    /// Check if this date represnt time in future
    var isPast: Bool {
        // TODO: rethink this implementation
        timeIntervalSinceNow < 0
    }
}
