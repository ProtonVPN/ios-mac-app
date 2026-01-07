//
//  Created on 2025-01-30.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import Dependencies

import CommonNetworking
import Connection
import VPNAppCore

import Domain
import Ergonomics
import Strings
import Timer

public struct OfferBannerViewModel {
    /// We refresh the time remaining label more often when it is below this value
    private static let refreshIntervalThreshold: TimeInterval = 120
    private static let quickRefreshInterval = Duration.seconds(1)
    private static let slowRefreshInterval = Duration.minutes(1)

    public var imageURL: URL
    public var endTime: Date
    public var showCountdown: Bool
    public var action: @MainActor (SessionService) async -> Void
    public var dismiss: () -> Void

    public init(
        imageURL: URL,
        endTime: Date,
        showCountdown: Bool,
        buttonURL: URL,
        offerReference: String?,
        dismiss: @escaping () -> Void
    ) {
        self.imageURL = imageURL
        self.endTime = endTime
        self.showCountdown = showCountdown
        self.dismiss = dismiss
        self.action = { _ in
            @Dependency(\.sessionService) var sessionService
            let url = await sessionService.getUpgradePlanSession(url: buttonURL.absoluteString)
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)
            AppEvent.userWasDisplayedAnnouncement.post(offerReference)
            AppEvent.userEngagedWithAnnouncement.post(offerReference)
        }
    }

    @Dependency(\.date) private var date
    @Dependency(\.locale) private var locale
    @Dependency(\.timeZone) private var timeZone

    private var relativeDateTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        formatter.locale = locale
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        formatter.calendar = calendar
        return formatter
    }

    public func timeLeftString() -> String? {
        let timeLeft = endTime.timeIntervalSince(date.now)
        guard timeLeft >= 0 else { return nil }
        let string = relativeDateTimeFormatter.localizedString(fromTimeInterval: timeLeft)
        return Localizable.offerEnding(string)
    }

    public func createTimer(updateTimeRemaining: @escaping () -> Void) -> Task<Void, Error> {
        let timeLeft = endTime.timeIntervalSince(date.now)
        let refreshInterval: Duration = (timeLeft < Self.refreshIntervalThreshold)
            ? Self.quickRefreshInterval
            : Self.slowRefreshInterval
        @Dependency(\.continuousClock) var clock
        return Task { @MainActor in
            for await _ in clock.timer(interval: refreshInterval) {
                updateTimeRemaining()
            }
        }
    }
}

#if DEBUG
    public extension OfferBannerViewModel {
        /// Fixed date for testing: 2026-01-15 12:00:00 UTC
        static let fixedCurrentDate = Date(timeIntervalSince1970: 1_736_942_400)

        static let withCountdown = OfferBannerViewModel(
            imageURL: URL(string: "https://example.com/offer.png")!,
            endTime: fixedCurrentDate.addingTimeInterval(3600), // 1 hour from fixed date
            showCountdown: true,
            buttonURL: URL(string: "https://example.com/upgrade")!,
            offerReference: "test-offer",
            dismiss: {}
        )

        static let withoutCountdown = OfferBannerViewModel(
            imageURL: URL(string: "https://example.com/offer.png")!,
            endTime: fixedCurrentDate.addingTimeInterval(86400), // 1 day from fixed date
            showCountdown: false,
            buttonURL: URL(string: "https://example.com/upgrade")!,
            offerReference: "test-offer",
            dismiss: {}
        )

        static let expiringSoon = OfferBannerViewModel(
            imageURL: URL(string: "https://example.com/offer.png")!,
            endTime: fixedCurrentDate.addingTimeInterval(60), // 1 minute from fixed date
            showCountdown: true,
            buttonURL: URL(string: "https://example.com/upgrade")!,
            offerReference: "test-offer",
            dismiss: {}
        )

        static let longDuration = OfferBannerViewModel(
            imageURL: URL(string: "https://example.com/offer.png")!,
            endTime: fixedCurrentDate.addingTimeInterval(604_800), // 1 week from fixed date
            showCountdown: true,
            buttonURL: URL(string: "https://example.com/upgrade")!,
            offerReference: "test-offer",
            dismiss: {}
        )
    }
#endif
