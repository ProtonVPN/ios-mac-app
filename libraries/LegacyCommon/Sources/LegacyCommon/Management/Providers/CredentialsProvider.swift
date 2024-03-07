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

import Foundation
import Dependencies

public struct CredentialsProvider {
    private var getCredentials: () -> CachedVpnCredentials?

    public var credentials: CachedVpnCredentials? { getCredentials() }
    public var planName: String { getCredentials()?.planName ?? "free" }
    public var tier: Int { getCredentials()?.maxTier ?? CoreAppConstants.VpnTiers.free }

    public init(getCredentials: @escaping () -> CachedVpnCredentials?) {
        self.getCredentials = getCredentials
    }
}

extension CredentialsProvider: DependencyKey {
    public static var liveValue: CredentialsProvider {
        return CredentialsProvider(getCredentials: {
            do {
                return try VpnKeychain.instance.fetchCached()
            } catch {
                log.warning("Failed to retrieve credentials: \(error)", category: .keychain)
                return nil
            }
        })
    }

    #if DEBUG
    public static var testValue: CredentialsProvider = .constant(credentials: .tier(CoreAppConstants.VpnTiers.plus))

    static func constant(credentials: CachedVpnCredentials?) -> CredentialsProvider {
        CredentialsProvider(getCredentials: { credentials })
    }
    #endif
}

extension DependencyValues {
    public var credentialsProvider: CredentialsProvider {
        get { self[CredentialsProvider.self] }
        set { self[CredentialsProvider.self] = newValue }
    }
}
