//
//  Created on 03/04/2025 by adam.
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

import Dependencies
import Domain
import Hermes
import ProtonCoreFeatureFlags
import Sharing

private extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var hermesEnabled: Self {
        self[.appStorage("HermesFeatureEnabled"), default: false]
    }
}

private extension SharedKey where Self == FileStorageKey<[HermesResolver]>.Default {
    static var hermesResolvers: Self {
        self[.fileStorage(.documentsDirectory.appending(component: HermesResolver.storagePathComponent)), default: []]
    }
}

extension HermesClient: @retroactive DependencyKey {
    @Shared(.hermesResolvers) private static var hermesResolvers

    public static let liveValue: HermesClient = .init {
        guard FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.customDNS) else { return .init(value: false) }
        @SharedReader(.hermesEnabled) var hermesEnabled: Bool
        return $hermesEnabled
    } setIsEnabled: { newValue in
        @Shared(.hermesEnabled) var hermesEnabled: Bool
        $hermesEnabled.withLock { $0 = newValue }
        AppEvent.hermes.post()
    } activeHermesResolvers: {
        @SharedReader(.hermesResolvers) var hermesResolvers
        return $hermesResolvers
    } validateHermesLocation: { location in
        HermesResolverLocationValidator.isValidIPv4(location) != nil
    } addHermesResolver: { newResolver in
        let newResolvers = hermesResolvers + [newResolver]
        $hermesResolvers.withLock { $0 = newResolvers }
        AppEvent.hermes.post()
        return true
    } removeHermesResolver: { index in
        var copy = hermesResolvers
        copy.remove(at: index)
        $hermesResolvers.withLock { $0 = copy }
        AppEvent.hermes.post()
        return true
    } applyDiff: { diff in
        var copy = hermesResolvers
        copy = copy.applying(diff) ?? copy
        $hermesResolvers.withLock { $0 = copy }
        AppEvent.hermes.post()
    }
}
