//
//  Offer.swift
//  vpncore - Created on 2020-10-13.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public struct Offer: Codable {
    public let label: String
    public let url: String
    public let icon: String
    public let panel: OfferPanel?
    
    // Our decoding strategy changes first letter to lowercase
    enum CodingKeys: String, CodingKey {
        case label
        case url = "URL"
        case icon
        case panel
    }
}

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
}

public struct FullScreenImage: Codable {
    public let source: [Source]
    public let alternativeText: String

    public struct Source: Codable {
        public let url: String
        public let type: String
        public let width: Int?
        public let target: String?

        enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case type
            case width
            case url = "URL"
            case target
        }
    }
}

public extension OfferPanel {
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

    enum Mode {
        case image(ImagePanel)
        case legacy(LegacyPanel)
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

public struct OfferFeature: Codable {
    public let iconURL: String
    public let text: String
}

public struct OfferButton: Codable {
    public let url: String
    public let text: String

    enum CodingKeys: String, CodingKey {
        case text
        case url = "URL"
    }
}
