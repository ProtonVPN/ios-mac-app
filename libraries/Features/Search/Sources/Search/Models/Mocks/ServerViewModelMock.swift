//
//  Created on 14.03.2022.
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
import ProtonCoreUIFoundations
import UIKit

final class ServerViewModelMock: ServerViewModel {
    var isRedesign: Bool = false

    var isPartnerServer: Bool

    var textColor: UIColor

    let description: String

    let isSmartAvailable: Bool

    let isTorAvailable: Bool

    let isP2PAvailable: Bool

    let isStreamingAvailable: Bool

    let connectIcon: UIImage?

    var textInPlaceOfConnectIcon: String? {
        isUsersTierTooLow ? "UPGRADE" : nil
    }

    var connectionChanged: (() -> Void)?

    let alphaOfMainElements: CGFloat = 1

    let isUsersTierTooLow: Bool

    var underMaintenance: Bool

    let connectButtonColor: UIColor = .darkGray

    let load: Int

    let loadColor: UIColor

    let city: String

    let entryCountryName: String?

    let entryCountryFlag: UIImage?

    let countryFlag: UIImage?

    let countryName: String

    let translatedCity: String?

    func connectAction() {}

    func partnersIcon(completion _: @escaping (UIImage?) -> Void) {}

    func cancelPartnersIconRequests() {}

    init(
        server: String,
        city: String,
        countryName: String,
        isUsersTierTooLow: Bool = false,
        entryCountryName: String? = nil,
        translatedCity: String? = nil,
        isPartnerServer: Bool = false,
        underMaintenance: Bool = false,
        connectIcon: UIImage? = nil,
        isSmartAvailable: Bool = false,
        isTorAvailable: Bool = false,
        isP2PAvailable: Bool = false,
        isStreamingAvailable: Bool = false,
        entryCountryFlag: UIImage? = nil,
        countryFlag: UIImage? = nil,
        load: Int = 56,
        loadColor: UIColor = .green
    ) {
        self.description = server
        self.city = city
        self.countryName = countryName
        self.isUsersTierTooLow = isUsersTierTooLow
        self.entryCountryName = entryCountryName
        self.translatedCity = translatedCity
        self.textColor = .white
        self.isPartnerServer = isPartnerServer
        self.underMaintenance = underMaintenance
        self.connectIcon = connectIcon
        self.isSmartAvailable = isSmartAvailable
        self.isTorAvailable = isTorAvailable
        self.isP2PAvailable = isP2PAvailable
        self.isStreamingAvailable = isStreamingAvailable
        self.entryCountryFlag = entryCountryFlag
        self.countryFlag = countryFlag
        self.load = load
        self.loadColor = loadColor
    }
}

extension ServerViewModelMock {
    static let normal = ServerViewModelMock(
        server: "US-NY#123",
        city: "New York",
        countryName: "United States",
        connectIcon: IconProvider.powerOff,
        isSmartAvailable: true,
        isTorAvailable: true,
        isP2PAvailable: true
    )

    static let secureCore = ServerViewModelMock(
        server: "CH-US#5",
        city: "New York",
        countryName: "United States",
        entryCountryName: "Switzerland",
        connectIcon: IconProvider.powerOff
    )

    static let underMaintenance = ServerViewModelMock(
        server: "UK-LON#45",
        city: "London",
        countryName: "United Kingdom",
        underMaintenance: true
    )

    static let upgrade = ServerViewModelMock(
        server: "NL-AMS#78",
        city: "Amsterdam",
        countryName: "Netherlands",
        isUsersTierTooLow: true,
        isSmartAvailable: true,
        isTorAvailable: true,
        isP2PAvailable: true
    )

    static let streaming = ServerViewModelMock(
        server: "US-CA#201",
        city: "Los Angeles",
        countryName: "United States",
        connectIcon: IconProvider.powerOff,
        isStreamingAvailable: true
    )

    static let highLoad = ServerViewModelMock(
        server: "FR-PAR#12",
        city: "Paris",
        countryName: "France",
        connectIcon: IconProvider.powerOff,
        isSmartAvailable: true,
        load: 89,
        loadColor: .systemRed
    )

    static let mediumLoad = ServerViewModelMock(
        server: "DE-BER#34",
        city: "Berlin",
        countryName: "Germany",
        connectIcon: IconProvider.powerOff,
        isP2PAvailable: true,
        load: 58,
        loadColor: .systemOrange
    )

    static let lowLoad = ServerViewModelMock(
        server: "JP-TKY#56",
        city: "Tokyo",
        countryName: "Japan",
        connectIcon: IconProvider.powerOff,
        isTorAvailable: true,
        load: 12,
        loadColor: .systemGreen
    )

    static let translatedCity = ServerViewModelMock(
        server: "ES-BCN#89",
        city: "Barcelona",
        countryName: "Spain",
        translatedCity: "Барселона",
        connectIcon: IconProvider.powerOff,
        isSmartAvailable: true
    )

    static let noFeatures = ServerViewModelMock(
        server: "CA-TOR#11",
        city: "Toronto",
        countryName: "Canada",
        connectIcon: IconProvider.powerOff
    )

    static let secureCoreWithFlags: ServerViewModelMock = {
        // Create mock flag images
        let size = CGSize(width: 30, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)

        // Swiss flag (entry)
        let swissFlag = renderer.image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 20))
        }

        // US flag (exit)
        let usFlag = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 10))
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 10, width: 30, height: 10))
        }

        return ServerViewModelMock(
            server: "CH-US#7",
            city: "New York",
            countryName: "United States",
            entryCountryName: "Switzerland",
            connectIcon: IconProvider.powerOff,
            entryCountryFlag: swissFlag,
            countryFlag: usFlag
        )
    }()
}
