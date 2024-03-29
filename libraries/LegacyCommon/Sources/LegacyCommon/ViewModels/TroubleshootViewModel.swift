//
//  TroubleshootViewModel.swift
//  vpncore - Created on 26.02.2021.
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
import Strings

public protocol TroubleshootViewModelFactory {
    func makeTroubleshootViewModel() -> TroubleshootViewModel
}

public final class TroubleshootViewModel {

    // Data
    public let items: [TroubleshootItem]

    // MARK: - Callbacks

    public var cancelled: (() -> Void)?

    public func cancel() {
        cancelled?()
    }

    // MARK: - Data

    private let supportEmail = "support@protonvpn.com"
    private let urlTor = "https://www.torproject.org"
    private let urlProtonStatus = "http://protonstatus.com"
    private let urlSupportForm = "https://protonvpn.com/support-form"
    private let urlTwitter = "https://twitter.com/ProtonVPN"

    public init(propertiesManager: PropertiesManagerProtocol) {
        items = [
            // Alternative routing
            AlternateRoutingTroubleshootItem(propertiesManager: propertiesManager),

            // No internet
            BasicTroubleshootItem(title: Localizable.troubleshootItemNointernetTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemNointernetDescription)),

            // ISP
            BasicTroubleshootItem(title: Localizable.troubleshootItemIspTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemIspDescription)
                                            .add(link: Localizable.troubleshootItemIspLink1, withUrl: urlTor)),

            // ISP
            BasicTroubleshootItem(title: Localizable.troubleshootItemGovTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemGovDescription)
                                            .add(link: Localizable.troubleshootItemGovLink1, withUrl: urlTor)),

            // Antivirus
            BasicTroubleshootItem(title: Localizable.troubleshootItemAntivirusTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemAntivirusDescription)),

            // Proxy / Firewall
            BasicTroubleshootItem(title: Localizable.troubleshootItemProxyTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemProxyDescription)),

            // Proton status
            BasicTroubleshootItem(title: Localizable.troubleshootItemProtonTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemProtonDescription)
                                            .add(link: Localizable.troubleshootItemProtonLink1, withUrl: urlProtonStatus)),

            // Contact / Other
            BasicTroubleshootItem(title: Localizable.troubleshootItemOtherTitle,
                                          description: NSMutableAttributedString(string: Localizable.troubleshootItemOtherDescription(supportEmail))
                                            .add(links: [
                                                (Localizable.troubleshootItemOtherLink1, urlSupportForm),
                                                (Localizable.troubleshootItemOtherLink2, String(format: "mailto:%@", supportEmail)),
                                                (Localizable.troubleshootItemOtherLink3, urlTwitter)
                                            ])),
        ]
    }

}
