//
//  TroubleshootViewModel.swift
//  vpncore - Created on 26.02.2021.
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

    private let supportEmail = "support@protonmail.com"
    private let urlTor = "https://www.torproject.org"
    private let urlProtonStatus = "http://protonstatus.com"
    private let urlSupportForm = "https://protonmail.com/support-form"
    private let urlTwitter = "https://twitter.com/ProtonMail"

    public init(propertiesManager: PropertiesManagerProtocol) {
        items = [
            // Alternative routing
            AlternateRoutingTroubleshootItem(propertiesManager: propertiesManager),

            // No internet
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleNoInternet,
                                          description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionNoInternet)),

            // ISP
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleISP,
                                          description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionISP)
                                            .add(link: LocalizedString.troubleshootItemLinkISP1, withUrl: urlTor)),

            // ISP
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleGovernment,
                                          description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionGovernment)
                                            .add(link: LocalizedString.troubleshootItemLinkGovernment1, withUrl: urlTor)),

            // Antivirus
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleAntivirus,
                                          description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionAntivirus)),

            // Proxy / Firewall
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleProxy,
                                          description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionProxy)),

            // Proton status
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleProton,
                                          description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionProton)
                                            .add(link: LocalizedString.troubleshootItemLinkProton1, withUrl: urlProtonStatus)),

            // Contact / Other
            BasicTroubleshootItem(title: LocalizedString.troubleshootItemTitleOther,
                                          description: NSMutableAttributedString(string: String(format: LocalizedString.troubleshootDescriptionOther, supportEmail))
                                            .add(links: [
                                                (LocalizedString.troubleshootItemLinkOther1, urlSupportForm),
                                                (LocalizedString.troubleshootItemLinkOther2, String(format: "mailto:%@", supportEmail)),
                                                (LocalizedString.troubleshootItemLinkOther3, urlTwitter)
                                            ])),
        ]
    }

}
