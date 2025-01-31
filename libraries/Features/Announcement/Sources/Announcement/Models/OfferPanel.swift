//
//  Created on 21/09/2022.
//
//  Copyright (c) 2022 Proton AG
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

public struct OfferPanel: Codable {
    public let fullScreenImage: FullScreenImage?
    public let button: OfferButton
    public let incentive: String?
    public let incentivePrice: String?
    public let pill: String?
    public let pictureURL: String?
    public let title: String?
    public let features: [OfferFeature]?
    public let featuresFooter: String?
    public let pageFooter: String?
    public let showCountdown: Bool?

    internal init(fullScreenImage: FullScreenImage? = nil,
                  button: OfferButton,
                  incentive: String? = nil,
                  incentivePrice: String? = nil,
                  pill: String? = nil,
                  pictureURL: String? = nil,
                  title: String? = nil,
                  features: [OfferFeature]? = nil,
                  featuresFooter: String? = nil,
                  pageFooter: String? = nil,
                  showCountdown: Bool? = nil) {
        self.fullScreenImage = fullScreenImage
        self.button = button
        self.incentive = incentive
        self.incentivePrice = incentivePrice
        self.pill = pill
        self.pictureURL = pictureURL
        self.title = title
        self.features = features
        self.featuresFooter = featuresFooter
        self.pageFooter = pageFooter
        self.showCountdown = showCountdown
    }
}
