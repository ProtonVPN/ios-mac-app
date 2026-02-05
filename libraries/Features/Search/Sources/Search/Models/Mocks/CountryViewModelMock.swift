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

final class CountryViewModelMock: CountryViewModel {
    func getStates() -> [CityViewModel] {
        []
    }

    var isGateway: Bool = false

    var isRedesign: Bool = false

    var showCountryConnectButton: Bool

    var showFeatureIcons: Bool = true

    let description: String

    let isSmartAvailable: Bool

    let torAvailable: Bool

    let p2pAvailable: Bool

    let connectIcon: UIImage?

    let textInPlaceOfConnectIcon: String?

    var connectionChanged: (() -> Void)?

    let alphaOfMainElements: CGFloat = 1

    let flag: UIImage?

    let connectButtonColor: UIColor = .darkGray

    let textColor: UIColor = .white

    let servers: [ServerTier: [ServerViewModel]]

    let isSecureCoreCountry: Bool

    func connectAction() {}

    let cities: [CityViewModel]

    init(
        country: String,
        servers: [ServerTier: [ServerViewModel]],
        isSecureCoreCountry: Bool = false,
        showCountryConnectButton: Bool = true,
        connectIcon: UIImage? = nil,
        isSmartAvailable: Bool = false,
        isTorAvailable: Bool = false,
        isP2PAvailable: Bool = false,
        textInPlaceOfConnectIcon: String? = nil,
        flag: UIImage? = nil
    ) {
        self.description = country
        self.servers = servers
        self.isSecureCoreCountry = isSecureCoreCountry
        self.showCountryConnectButton = showCountryConnectButton

        let servers = ServerTier.sorted(by: .plus).flatMap { servers[$0] ?? [] }
        let groups = Dictionary(grouping: servers, by: { $0.city })
        self.cities = groups.map {
            CityViewModelMock(cityName: $0.key, countryName: country, translatedCityName: $0.value.first?.translatedCity)
        }.sorted(by: { $0.cityName < $1.cityName })
        self.connectIcon = connectIcon
        self.isSmartAvailable = isSmartAvailable
        self.torAvailable = isTorAvailable
        self.p2pAvailable = isP2PAvailable
        self.textInPlaceOfConnectIcon = textInPlaceOfConnectIcon
        self.flag = flag
    }

    func getServers() -> [ServerTier: [ServerViewModel]] {
        servers
    }

    func getCities() -> [CityViewModel] {
        cities
    }
}

extension CountryViewModelMock {
    static let normal = CountryViewModelMock(
        country: "Country",
        servers: [.free: [ServerViewModelMock.normal]],
        connectIcon: IconProvider.powerOff,
        isSmartAvailable: true,
        isTorAvailable: true,
        isP2PAvailable: true
    )

    static let upgrade = CountryViewModelMock(
        country: "Country",
        servers: [.plus: [ServerViewModelMock.normal]],
        isSmartAvailable: true,
        isTorAvailable: true,
        isP2PAvailable: true,
        textInPlaceOfConnectIcon: "Upgrade"
    )

    static let secureCore = CountryViewModelMock(
        country: "Switzerland",
        servers: [.plus: [ServerViewModelMock.normal]],
        isSecureCoreCountry: true,
        connectIcon: IconProvider.powerOff,
        isSmartAvailable: true,
        isTorAvailable: true,
        isP2PAvailable: true
    )

    static let noConnectButton = CountryViewModelMock(
        country: "United States",
        servers: [.free: [ServerViewModelMock.normal]],
        showCountryConnectButton: false,
        isSmartAvailable: false,
        isTorAvailable: false,
        isP2PAvailable: false
    )

    static let noFeatureIcons = CountryViewModelMock(
        country: "Germany",
        servers: [.free: [ServerViewModelMock.normal]],
        connectIcon: IconProvider.powerOff
    )

    static let withFlag: CountryViewModelMock = {
        // Create a simple colored rectangle as a mock flag
        let size = CGSize(width: 30, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        let flagImage = renderer.image { context in
            // Dutch flag colors (red, white, blue)
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 7))
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 7, width: 30, height: 6))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 13, width: 30, height: 7))
        }
        return CountryViewModelMock(
            country: "Netherlands",
            servers: [.free: [ServerViewModelMock.normal]],
            connectIcon: IconProvider.powerOff,
            isSmartAvailable: true,
            isTorAvailable: false,
            isP2PAvailable: true,
            flag: flagImage
        )
    }()
}
