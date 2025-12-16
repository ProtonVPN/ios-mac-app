//
//  Created on 16/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Domain
import Foundation
import Strings

@Reducer
public struct TroubleshootFeature {
    @ObservableState
    public struct State: Equatable {
        static let supportEmail = "support@protonvpn.com"
        static let urlTor = "https://www.torproject.org"
        static let urlProtonStatus = "http://protonstatus.com"
        static let urlSupportForm = "https://protonvpn.com/support-form"
        static let urlTwitter = "https://twitter.com/ProtonVPN"

        public var items: IdentifiedArrayOf<TroubleshootItem.State>

        public init() {
            self.items = [
                // Alternative routing
                TroubleshootItem.State(
                    id: 1,
                    title: Localizable.troubleshootItemAltTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemAltDescription)
                        .add(link: Localizable.troubleshootItemAltLink1, withUrl: VPNLink.alternativeRouting.urlString),
                    type: .alternativeRouting
                ),

                // No internet
                TroubleshootItem.State(
                    id: 2,
                    title: Localizable.troubleshootItemNointernetTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemNointernetDescription),
                    type: .basic
                ),

                // ISP
                TroubleshootItem.State(
                    id: 3,
                    title: Localizable.troubleshootItemIspTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemIspDescription)
                        .add(link: Localizable.troubleshootItemIspLink1, withUrl: State.urlTor),
                    type: .basic
                ),

                // Government
                TroubleshootItem.State(
                    id: 4,
                    title: Localizable.troubleshootItemGovTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemGovDescription)
                        .add(link: Localizable.troubleshootItemGovLink1, withUrl: State.urlTor),
                    type: .basic
                ),

                // Antivirus
                TroubleshootItem.State(
                    id: 5,
                    title: Localizable.troubleshootItemAntivirusTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemAntivirusDescription),
                    type: .basic
                ),

                // Proxy / Firewall
                TroubleshootItem.State(
                    id: 6,
                    title: Localizable.troubleshootItemProxyTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemProxyDescription),
                    type: .basic
                ),

                // Proton status
                TroubleshootItem.State(
                    id: 7,
                    title: Localizable.troubleshootItemProtonTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemProtonDescription)
                        .add(link: Localizable.troubleshootItemProtonLink1, withUrl: State.urlProtonStatus),
                    type: .basic
                ),

                // Contact / Other
                TroubleshootItem.State(
                    id: 8,
                    title: Localizable.troubleshootItemOtherTitle,
                    description: NSMutableAttributedString(string: Localizable.troubleshootItemOtherDescription(State.supportEmail))
                        .add(links: [
                            (Localizable.troubleshootItemOtherLink1, State.urlSupportForm),
                            (Localizable.troubleshootItemOtherLink2, String(format: "mailto:%@", State.supportEmail)),
                            (Localizable.troubleshootItemOtherLink3, State.urlTwitter),
                        ]),
                    type: .basic
                ),
            ]
        }
    }

    public enum Action {
        case closeButtonTapped
        case troubleshootItem(IdentifiedActionOf<TroubleshootItem>)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .closeButtonTapped:
                .none

            case .troubleshootItem:
                .none
            }
        }
        .forEach(\.items, action: \.troubleshootItem) {
            TroubleshootItem()
        }
    }
}
