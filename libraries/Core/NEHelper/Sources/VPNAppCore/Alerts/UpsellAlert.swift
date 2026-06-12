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

    open func continueAction() {}

    public init() {}
}

public enum UpsellModalSource: Sendable {
    case secureCore
    case netShield
    case countries
    case tor
    case portForwarding
    case profiles
    case vpnAccelerator
    case splitTunneling
    case allowLan
    case moderateNat
    case promoOffer
    case hermes
}

public final class AllCountriesUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .countries
    }
}

public final class NetShieldUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .netShield
    }
}

public final class SecureCoreUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .secureCore
    }
}

public final class VPNAcceleratorUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .vpnAccelerator
    }
}

public final class PortForwardingUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .portForwarding
    }
}

public final class TorUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .tor
    }
}

public final class CustomizationUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .allowLan
    }
}

public final class ProfilesUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource {
        .profiles
    }
}

public final class ModerateNATUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .moderateNat
    }
}

public final class HermesUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .hermes
    }
}

public final class PlutoniumUpsellAlert: UpsellAlert {
    override public var modalSource: UpsellModalSource? {
        .splitTunneling
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

    override public var modalSource: UpsellModalSource? {
        nil
    }
}
