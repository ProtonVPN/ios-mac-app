//
//  Created on 10/08/2023.
//
//  Copyright (c) 2023 Proton AG
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
import DependenciesMacros
import Domain
import Foundation
import VPNShared

/// Provides non-secret VPN account credentials to application features.
@DependencyClient
public struct CredentialsProvider {
    /// Reads the non-secret subset of the currently stored VPN credentials.
    public var getCredentials: () -> CachedVpnCredentials?
}

public extension CredentialsProvider {
    /// The non-secret subset of the currently stored VPN credentials.
    var credentials: CachedVpnCredentials? {
        getCredentials()
    }

    /// Whether VPN credentials are currently available.
    var hasCredentials: Bool {
        credentials != nil
    }

    /// The API plan name, falling back to the free plan when credentials are unavailable.
    var planName: String {
        credentials?.planName ?? "free"
    }

    /// The localized plan title, if credentials are available.
    var planTitle: String? {
        credentials?.planTitle
    }

    /// The maximum VPN tier, falling back to the free tier when credentials are unavailable.
    var tier: VpnTier {
        credentials?.maxTier ?? .free
    }

    /// Whether the current account is a business account.
    var isBusiness: Bool {
        credentials?.isBusiness ?? false
    }

    /// Whether business telemetry events are enabled for the current account.
    var businessEvents: Bool {
        credentials?.businessEvents ?? false
    }

    /// The NetShield settings associated with the current account.
    var netShield: NetShieldFeatureSettings? {
        credentials?.netshield
    }
}

extension CredentialsProvider: DependencyKey {
    public static var liveValue: CredentialsProvider {
        // Provider values are captured into escaped contexts, where a deferred
        // `@Dependency` lookup would resolve outside any dependency scope
        @Dependency(\.vpnKeychain) var vpnKeychain
        return CredentialsProvider(
            getCredentials: {
                try? vpnKeychain.fetchCached()
            }
        )
    }

    #if DEBUG
        public static var testValue: CredentialsProvider {
            .constant(credentials: .tier(.paid))
        }

        /// Creates a provider that always returns `credentials`.
        public static func constant(credentials: CachedVpnCredentials?) -> CredentialsProvider {
            CredentialsProvider(getCredentials: { credentials })
        }
    #endif
}

public extension DependencyValues {
    /// Provides non-secret VPN account credentials.
    var credentialsProvider: CredentialsProvider {
        get { self[CredentialsProvider.self] }
        set { self[CredentialsProvider.self] = newValue }
    }
}
