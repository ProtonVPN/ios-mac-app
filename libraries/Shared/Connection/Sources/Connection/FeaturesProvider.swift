//
//  Created on 10/12/2024.
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
import DependenciesMacros
import Domain
import Foundation

@available(iOS 16, tvOS 17, *)
public struct VPNConnectionFeaturesProvider: Sendable {
    public internal(set) var connectionFeatures: @Sendable () -> VPNConnectionFeatures
    public internal(set) var setConnectionFeatures: @Sendable (_: VPNConnectionFeatures) -> Void

    public init(
        connectionFeatures: @escaping @Sendable () -> VPNConnectionFeatures = { .unimplementedFeatures },
        setConnectionFeatures: @escaping @Sendable (_: VPNConnectionFeatures) -> Void = { _ in reportIssue() }
    ) {
        self.connectionFeatures = connectionFeatures
        self.setConnectionFeatures = setConnectionFeatures
    }
}

extension VPNConnectionFeaturesProvider: TestDependencyKey {
    public static let testValue: VPNConnectionFeaturesProvider = .init()
}

extension DependencyValues {
    public var vpnFeaturesProvider: VPNConnectionFeaturesProvider {
        get { self[VPNConnectionFeaturesProvider.self] }
        set { self[VPNConnectionFeaturesProvider.self] = newValue }
    }
}

extension VPNConnectionFeatures {
    @usableFromInline
    static let unimplementedFeatures: VPNConnectionFeatures = {
        VPNConnectionFeatures(
            netshield: .off,
            vpnAccelerator: false,
            bouncing: nil, // This is set to the target server's `label` property during connection
            natType: .moderateNAT,
            safeMode: false
        )
    }()
}
