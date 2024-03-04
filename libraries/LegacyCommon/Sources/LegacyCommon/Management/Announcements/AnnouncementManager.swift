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

import Foundation

public protocol AnnouncementManager {
    var hasUnreadAnnouncements: Bool { get }
    func fetchCurrentAnnouncementsFromStorage() -> [Announcement]
    func fetchCurrentOfferBannerFromStorage() -> Announcement?
    func offerBannerViewModel(dismiss: @escaping (Announcement) -> Void) -> OfferBannerViewModel?
    func markAsRead(announcement: Announcement)
    func shouldShowAnnouncementsIcon() -> Bool
}

public protocol AnnouncementManagerFactory {
    func makeAnnouncementManager() -> AnnouncementManager
}

/// Fetches announcements from storage.
/// Informs if there are any unread current announcements.
/// Marks announcements as read.
public class AnnouncementManagerImplementation: AnnouncementManager {
    
    public typealias Factory = AnnouncementStorageFactory
    private let factory: Factory
    
    private lazy var announcementStorage: AnnouncementStorage = factory.makeAnnouncementStorage()
    
    public init(factory: Factory) {
        self.factory = factory
    }

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
        return OfferBannerViewModel(imageURL: imageURL,
                                    endTime: offerBanner.endTime,
                                    showCountDown: offerBanner.offer?.panel?.showCountDown ?? false,
                                    buttonURL: buttonURL,
                                    offerReference: offerBanner.reference,
                                    dismiss: { dismiss(offerBanner) })
    }

    public func fetchCurrentOfferBannerFromStorage() -> Announcement? {
        let offers = announcementStorage.fetch().filter {
            $0.knownType == .banner && $0.startTime.isPast && $0.endTime.isFuture && $0.offer != nil
        }.sorted { // sorting is needed because we only want to consider the first announcement
            $0.endTime < $1.endTime
        }
        if offers.count > 1 {
            let errorMessage = "There should only ever be one or none welcome offer banner, having more is an error."
            log.assertionFailure(errorMessage)
            log.error(.init(stringLiteral: errorMessage), category: .api)
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
        var announcements = announcementStorage.fetch()
        if let index = announcements.firstIndex(where: { $0.notificationID == announcement.notificationID }) {
            announcements[index].isRead = true
        }
        announcementStorage.store(announcements)
    }
    
}
