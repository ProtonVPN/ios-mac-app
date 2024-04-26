//
//  Created on 11/01/2024.
//
//  Copyright (c) 2024 Proton AG
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
import Strings
import Timer

public struct OfferBannerViewModel {

    static let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter
    }()

    public var imageURL: URL
    public var endTime: Date
    public var showCountdown: Bool
    public var action: @MainActor () -> Void
    public var dismiss: () -> Void

    public init(imageURL: URL,
                endTime: Date,
                showCountdown: Bool,
                buttonURL: URL,
                offerReference: String?,
                dismiss: @escaping () -> Void) {
        self.imageURL = imageURL
        self.endTime = endTime
        self.showCountdown = showCountdown
        self.dismiss = dismiss
        self.action = {
            SafariService.openLink(url: buttonURL)
            NotificationCenter.default.post(name: .userWasDisplayedAnnouncement,
                                            object: offerReference)
            NotificationCenter.default.post(name: .userEngagedWithAnnouncement,
                                            object: offerReference)
        }
    }

    public func timeLeftString() -> String? {
        let timeLeft = endTime.timeIntervalSinceNow
        guard timeLeft >= 0 else { return nil }
        let string = Self.relativeDateTimeFormatter.localizedString(fromTimeInterval: timeLeft)
        return Localizable.offerEnding(string)
    }

    public func createTimer(updateTimeRemaining: @escaping () -> Void) -> BackgroundTimer {
        let timeLeft = endTime.timeIntervalSinceNow
        let repeating: Double? = timeLeft < 120 ? 1 : 60
        return ForegroundTimerFactoryImplementation().scheduledTimer(runAt: Date(),
                                                                     repeating: repeating,
                                                                     leeway: nil,
                                                                     queue: .main) {
            updateTimeRemaining()
        }
    }
}
