//
//  AnnouncementManagerImplementationTests.swift
//  vpncore - Created on 2020-10-19.
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

@testable import Announcement
import Dependencies
import Foundation
import Sharing
import Testing
import VPNShared

extension Offer {
    static let empty: Offer = .init(label: "", icon: "", panel: nil)
}

struct AnnouncementManagerImplementationTests {
    private static let announcements: [Announcement] = [
        Announcement(
            notificationID: "1-no-offer",
            startTime: Date(),
            endTime: .distantFuture,
            type: Announcement.NotificationType.default.rawValue,
            offer: nil,
            reference: nil
        ),
        Announcement(
            notificationID: "2-with-offer",
            startTime: Date(),
            endTime: .distantFuture,
            type: Announcement.NotificationType.default.rawValue,
            offer: .empty,
            reference: nil
        ),
        Announcement(
            notificationID: "3-with-offer",
            startTime: Date(),
            endTime: .distantFuture,
            type: Announcement.NotificationType.default.rawValue,
            offer: .empty,
            reference: nil
        ),
        Announcement(
            notificationID: "2-with-offer-one-time",
            startTime: Date(),
            endTime: .distantFuture,
            type: Announcement.NotificationType.oneTime.rawValue,
            offer: .empty,
            reference: nil
        ),
        Announcement(
            notificationID: "3-ended",
            startTime: .distantPast,
            endTime: .distantPast,
            type: Announcement.NotificationType.default.rawValue,
            offer: .empty,
            reference: nil
        ),
        Announcement(
            notificationID: "3-future",
            startTime: .distantFuture,
            endTime: .distantFuture,
            type: Announcement.NotificationType.default.rawValue,
            offer: .empty,
            reference: nil
        ),
    ]

    private func withManager<T>(_ body: (AnnouncementManager) throws -> T) rethrows -> T {
        let keychain = MockAuthKeychain()
        keychain.setMockUsername("test-user")
        return try withDependencies {
            $0.authKeychain = keychain
        } operation: {
            @Shared(.announcements) var announcements: [Announcement]?
            $announcements.withLock { $0 = Self.announcements }
            return try body(.liveValue)
        }
    }

    @Test
    func fetchesOnlyCurrentNotifications() {
        withManager { manager in
            let filtered = manager.fetchCurrentAnnouncementsFromStorage()
            #expect(filtered.containsAnnouncement(withId: "2-with-offer"))
            #expect(filtered.containsAnnouncement(withId: "2-with-offer-one-time"))
            #expect(filtered.count == 3)
            #expect(!filtered.containsAnnouncement(withId: "1-no-offer"))
            #expect(!filtered.containsAnnouncement(withId: "3-ended"))
            #expect(!filtered.containsAnnouncement(withId: "3-future"))
        }
    }

    @Test
    func marksAsRead() {
        withManager { manager in
            let announcement = manager.fetchCurrentAnnouncementsFromStorage()[0]
            #expect(!announcement.wasRead)
            manager.markAsRead(announcement: announcement)
            let announcement2 = manager.fetchCurrentAnnouncementsFromStorage()[0]
            #expect(announcement2.wasRead)
        }
    }

    @Test
    func distinguishesWhenUnreadAnnsArePresent() {
        withManager { manager in
            #expect(manager.hasUnreadAnnouncements())
            for item in manager.fetchCurrentAnnouncementsFromStorage() {
                manager.markAsRead(announcement: item)
            }
            #expect(!manager.hasUnreadAnnouncements())
        }
    }

    @Test
    func showsOnlyFirstAnnouncement() throws {
        try withManager { manager in
            #expect(manager.hasUnreadAnnouncements())
            #expect(manager.shouldShowAnnouncementsIcon())
            // read the first one
            let announcements = manager.fetchCurrentAnnouncementsFromStorage()
            let active = announcements.filter { $0.knownType == .default && !$0.wasRead }
            #expect(active.count > 1)
            let first = try #require(announcements.first { $0.knownType == .default })
            manager.markAsRead(announcement: first)
            #expect(!manager.hasUnreadAnnouncements())
            #expect(manager.shouldShowAnnouncementsIcon())
        }
    }
}
