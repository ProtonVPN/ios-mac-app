//
//  Created on 23/10/2024.
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

import Dependencies

public protocol SystemAlert: AnyObject {
    var title: String? { get set }
    var message: String? { get set }
    var actions: [AlertAction] { get set }
    var isError: Bool { get }
    var dismiss: (() -> Void)? { get set }
}

public enum PrimaryActionType {
    case confirmative
    case destructive
    case secondary
    case cancel
}

public struct AlertAction {
    public let title: String
    public let style: PrimaryActionType
    public let handler: (() -> Void)?

    public init(title: String, style: PrimaryActionType, handler: (() -> Void)?) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

open class UpsellAlert: SystemAlert {
    open var title: String?
    open var message: String?
    open var actions = [AlertAction]()
    open var isError = false
    open var dismiss: (() -> Void)?
    open var modalSource: UpsellModalSource? {
        log.assertionFailure("Not implemented")

        return nil
    }

    open func continueAction() { }

    public init() { }

}

public enum UpsellModalSource {
    case secureCore
    case netShield
    case countries
    case p2p
    case streaming
    case portForwarding
    case profiles
    case vpnAccelerator
    case splitTunneling
    case customDns
    case allowLan
    case moderateNat
    case safeMode
    case changeServer
    case promoOffer
    case downgrade
    case maxConnections
}

public class AllCountriesUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .countries }
}
