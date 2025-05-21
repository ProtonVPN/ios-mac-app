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

import Dependencies
import Foundation
import VPNShared

public enum AnnouncementManagerKey: DependencyKey {
    public static let liveValue: any AnnouncementManager = AnnouncementManagerImplementation()
}

#if DEBUG
    extension AnnouncementManagerKey: TestDependencyKey {
        public static let previewValue: any AnnouncementManager = AnnouncementManagerImplementation()
        public static let testValue: any AnnouncementManager = AnnouncementManagerImplementation()
    }
#endif

public enum AnnouncementStorageKey: DependencyKey {
    public static let liveValue: any AnnouncementStorage = {
        @Dependency(\.defaultsProvider) var provider
        return AnnouncementStorageUserDefaults(userDefaults: provider.getDefaults(), keyNameProvider: nil)
    }()
}

public enum AnnouncementRefresherKey: DependencyKey {
    public static let liveValue: any AnnouncementRefresher = AnnouncementRefresherImplementation()
}

#if DEBUG
    extension AnnouncementStorageKey: TestDependencyKey {
        public static let previewValue: any AnnouncementStorage = AnnouncementStorageMock()
        public static let testValue: any AnnouncementStorage = AnnouncementStorageMock()
    }
#endif

public extension DependencyValues {
    var announcementManager: AnnouncementManager {
        get { self[AnnouncementManagerKey.self] }
        set { self[AnnouncementManagerKey.self] = newValue }
    }

    var announcementStorage: AnnouncementStorage {
        get { self[AnnouncementStorageKey.self] }
        set { self[AnnouncementStorageKey.self] = newValue }
    }

    var announcementRefresher: AnnouncementRefresher {
        get { self[AnnouncementRefresherKey.self] }
        set { self[AnnouncementRefresherKey.self] = newValue }
    }
}

public protocol AnnouncementManager {
    var hasUnreadAnnouncements: Bool { get }
    func fetchCurrentAnnouncementsFromStorage() -> [Announcement]
    func fetchCurrentOfferBannerFromStorage() -> Announcement?
    func offerBannerViewModel(dismiss: @escaping (Announcement) -> Void) -> OfferBannerViewModel?
    func markAsRead(announcement: Announcement)
    func markAsRead(notificationID: String)
    func shouldShowAnnouncementsIcon() -> Bool
}

public extension AnnouncementManager {
    static var notification: Notification.Name {
        .init("Announcements")
    }
}

/// Fetches announcements from storage.
/// Informs if there are any unread current announcements.
/// Marks announcements as read.
public class AnnouncementManagerImplementation: AnnouncementManager {
    @Dependency(\.announcementStorage) private var announcementStorage: AnnouncementStorage

    public func shouldShowAnnouncementsIcon() -> Bool {
        fetchCurrentAnnouncementsFromStorage().contains(where: { $0.knownType == .default })
    }

    public func offerBannerViewModel(dismiss: @escaping (Announcement) -> Void) -> OfferBannerViewModel? {
        guard let offerBanner = fetchCurrentOfferBannerFromStorage(),
              let url = offerBanner.offer?.panel?.fullScreenImage?.source.first?.url,
              let imageURL = URL(string: url),
              let buttonURLString = offerBanner.offer?.panel?.button.url,
              let buttonURL = URL(string: buttonURLString) else {
            return nil
        }
        return OfferBannerViewModel(
            imageURL: imageURL,
            endTime: offerBanner.endTime,
            showCountdown: offerBanner.offer?.panel?.showCountdown ?? false,
            buttonURL: buttonURL,
            offerReference: offerBanner.reference,
            dismiss: { dismiss(offerBanner) }
        )
    }

    public func fetchCurrentOfferBannerFromStorage() -> Announcement? {
        let offers = announcementStorage.fetch().filter {
            $0.knownType == .banner && $0.startTime.isPast && $0.endTime.isFuture && $0.offer != nil
        }.sorted { // sorting is needed because we only want to consider the first announcement
            $0.endTime < $1.endTime
        }
        if offers.count > 1 {
            log.error("There should only ever be one or none welcome offer banner, having more is an error.")
        }
        // Only return the one with closest endTime. If the offer was read, return nothing, though there might be others in queue.
        // This should not really happen, it would be a configuration error if it did.
        return offers.first?.isRead == false ? offers.first : nil
    }

    public func fetchCurrentAnnouncementsFromStorage() -> [Announcement] {
        announcementStorage.fetch().filter {
            $0.startTime.isPast && $0.endTime.isFuture && $0.offer != nil
        }.sorted { // sorting is needed because we only want to consider the first announcement
            $0.startTime < $1.startTime
        }
    }

    public var hasUnreadAnnouncements: Bool {
        let announcement = fetchCurrentAnnouncementsFromStorage()
            .filter { $0.knownType == .default }
            .first
        guard let announcement else { return false }
        return !announcement.wasRead
    }

    public func markAsRead(announcement: Announcement) {
        markAsRead(notificationID: announcement.notificationID)
    }

    public func markAsRead(notificationID: String) {
        var announcements = announcementStorage.fetch()
        if let index = announcements.firstIndex(where: { $0.notificationID == notificationID }) {
            announcements[index].isRead = true
            announcementStorage.store(announcements)
        }
    }
}

// MARK: - Mocks

#if DEBUG
    import Domain

    public final class AnnouncementStorageMock: AnnouncementStorage {
        public var announcements: [Announcement]

        public init(_ announcements: [Announcement] = []) {
            self.announcements = announcements
        }

        public func fetch() -> [Announcement] {
            announcements
        }

        public func store(_ objects: [Announcement]) {
            announcements = objects
            AppEvent.announcementStorageContent.post(objects)
        }

        public func clear() {
            announcements = []
        }
    }
#endif

public extension Date {
    /// Check if this date represnt time in future
    var isFuture: Bool {
        timeIntervalSinceNow > 0
    }

    /// Check if this date represnt time in future
    var isPast: Bool {
        timeIntervalSinceNow < 0
    }
}
