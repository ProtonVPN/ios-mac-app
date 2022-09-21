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

public extension OfferPanel {

    enum Mode {
        case image(ImagePanel)
        case legacy(LegacyPanel)
    }

    func panelMode() -> Mode? {
        if let fullScreenImage = fullScreenImage {
            let panel = ImagePanel(fullScreenImage: fullScreenImage, button: button)
            return .image(panel)
        }
        guard let incentive = incentive,
              let incentivePrice = incentivePrice,
              let pill = pill,
              let pictureURL = pictureURL,
              let title = title,
              let features = features,
              let featuresFooter = featuresFooter,
              let pageFooter = pageFooter else {
            return nil
        }
        let panel = LegacyPanel(button: button,
                                incentive: incentive,
                                incentivePrice: incentivePrice,
                                pill: pill,
                                pictureURL: pictureURL,
                                title: title,
                                features: features,
                                featuresFooter: featuresFooter,
                                pageFooter: pageFooter)
        return .legacy(panel)
    }

    struct LegacyPanel {
        public let button: OfferButton
        public let incentive: String
        public let incentivePrice: String
        public let pill: String
        public let pictureURL: String
        public let title: String
        public let features: [OfferFeature]
        public let featuresFooter: String
        public let pageFooter: String
    }

    struct ImagePanel {
        public let fullScreenImage: FullScreenImage
        public let button: OfferButton
    }
}
