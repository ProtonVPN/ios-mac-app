//
//  News.swift
//  vpncore - Created on 2020-10-05.
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

/// API calls this thing Notification
public struct Announcement: Codable {
    
    public let notificationID: String
    public let startTime: Date
    public let endTime: Date
    public let type: NotificationType
    public let offer: Offer?
    
    // Is set from the app, NOT api
    public var isRead: Bool? = false
    
    // Wrapper param that returns false in case isRead is nil
    public var wasRead: Bool {
        return isRead == true
    }
    
    mutating func setAsRead(_ read: Bool) {
        isRead = read
    }
}

extension Announcement {
    public enum NotificationType: Int, Codable {
        case `default` = 0
        case oneTime = 1
    }
}

extension Announcement {

    var fullScreenImage: FullScreenImage? {
        guard case .image(let panel) = offer?.panel?.panelMode() else {
            return nil
        }
        return panel.fullScreenImage
    }

    var prefetchableImage: URL? {
        guard let url = fullScreenImage?.firstURL else {
            return nil
        }
        return url
    }

    public func isImagePrefetched(imageCache: ImageCacheFactoryProtocol) async -> Bool {
        guard let fullScreenImage = fullScreenImage else {
            return false
        }
        let prefetcher = FullScreenImagePrefetcher(imageCache)
        return await prefetcher.isImagePrefetched(fullScreenImage: fullScreenImage)
    }
}
