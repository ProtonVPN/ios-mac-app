//
//  Created on 13.03.2025 by John Biggs.
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

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

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
    case tor
    case streaming
    case devices
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

public final class AllCountriesUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .countries }
}

public final class NetShieldUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .netShield }
}

public final class SecureCoreUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .secureCore }
}

public final class VPNAcceleratorUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .vpnAccelerator }
}

public final class StreamingUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .streaming }
}

public final class P2PUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .p2p }
}

public final class DevicesUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .devices }
}

public final class TorUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .tor }
}

public final class CustomizationUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .allowLan }
}


public final class ProfilesUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource { .profiles }
}

public final class CountryUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .countries }

    public let countryCode: String
    public init(countryCode: String) {
        self.countryCode = countryCode
    }
}

public final class SafeModeUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .safeMode }
}

public final class ModerateNATUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .moderateNat }
}

public final class ConnectionCooldownAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .changeServer }

    public let until: Date
    public let duration: TimeInterval
    public let longSkip: Bool

    public init(
        until: Date,
        duration: TimeInterval,
        longSkip: Bool,
        reconnectClosure: @escaping (() -> Void)
    ) {
        self.until = until
        self.duration = duration
        self.longSkip = longSkip

        super.init()
        actions = [.init(
            title: "Reconnect",
            style: .confirmative,
            handler: reconnectClosure
        )]
    }

    override public func continueAction() {
        actions.first(where: { $0.style == .confirmative })?
            .handler?()
    }
}

public final class WelcomeScreenAlert: UpsellAlert {
    /// This enum is used to narrow down the possible types of this alert. Theoretically we could just allow to use the `ModalType`
    /// but we don't want to use this alert (for now) for anything else than welcome alerts.
    public enum Plan {
        case plus(numberOfServers: Int, numberOfDevices: Int, numberOfCountries: Int)
        case unlimited
        case fallback
    }
    public let plan: Plan

    public init(plan: Plan) {
        self.plan = plan
    }

    public override var modalSource: UpsellModalSource? {
        return nil
    }
}
