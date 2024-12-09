//
//  Created on 06/12/2024.
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

import Foundation
import Collections
import Dependencies
import DependenciesMacros
import SharedViews
import Domain

@DependencyClient
struct DefaultConnectionResolver: Sendable {
    @DependencyEndpoint
    private var connectionSpec: (
        _ preference: DefaultConnectionPreference,
        _ recents: OrderedSet<RecentConnection>,
        _ isSecureCoreEnabled: Bool
    ) -> ConnectionSpec = { _, _, _ in .defaultFastest }

    @DependencyEndpoint
    private var preferenceModels: @Sendable (
        _ recents: OrderedSet<RecentConnection>
    ) -> [ConnectionPreferenceModel] = { _ in XCTFail("\(Self.self).preferenceModels"); return [] }
}

extension DefaultConnectionResolver: DependencyKey {
    static let liveValue = DefaultConnectionResolver(
        connectionSpec: DefaultConnectionResolverImplementation.connectionSpec(for:recents:isSecureCoreEnabled:),
        preferenceModels: DefaultConnectionResolverImplementation.preferenceModels(for:)
    )
}

enum DefaultConnectionResolverImplementation {
    static func connectionSpec(
        for preference: DefaultConnectionPreference,
        recents: OrderedSet<RecentConnection>,
        isSecureCoreEnabled: Bool
    ) -> ConnectionSpec {
        // Fastest overall connection doesn't take secure core into account.
        // Check `DefaultConnectionPreference.fastest` docs for reasoning.
        let fastestNonSecureCore = ConnectionSpec(location: .fastest, features: [])

        switch preference {
        case .fastest:
            return fastestNonSecureCore

        case .mostRecent:
            guard let mostRecent = recents.mostRecent else {
                log.info("No recent connections, returning fastest", metadata: ["preference": "\(preference)"])
                return fastestNonSecureCore
            }
            return mostRecent.connection

        case .recent(let spec):
            return spec
        }
    }

    static func shouldOfferDefaultConnectionPreference(for recent: RecentConnection) -> Bool {
        // 'Fastest' is already a static preference, so lets not offer it as an option
        return recent.connection.location != .fastest
    }

    @Sendable
    static func preferenceModels(for recents: OrderedSet<RecentConnection>) -> [ConnectionPreferenceModel] {
        return recents
            .filter(shouldOfferDefaultConnectionPreference(for:))
            .map { recent in
            let spec = recent.connection
            let infoBuilder = ConnectionInfoBuilder(intent: spec, vpnConnectionActual: nil, withServerNumber: false)

            return ConnectionPreferenceModel(
                preference: .recent(spec),
                locationFeatureModel: .init(
                    flag: spec.location.flagComposition,
                    header: .init(title: infoBuilder.textHeader, showConnectedPin: false),
                    subheader: infoBuilder.subheader
                )
            )
        }
    }
}

extension DependencyValues {
    var defaultConnectionResolver: DefaultConnectionResolver {
        get { self[DefaultConnectionResolver.self] }
        set { self[DefaultConnectionResolver.self] = newValue }
    }
}
