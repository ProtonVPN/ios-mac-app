//
//  Created on 19/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

// TODO: SharedInterfaces module in Shared instead of Foundation?
public struct ServerSelector: Sendable {
    public internal(set) var select: @Sendable (
        _ spec: ConnectionSpec,
        _ userTier: Int,
        _ acceptableProtocols: ProtocolSupport
    ) throws -> Server

    public init(select: @escaping @Sendable (_: ConnectionSpec, _: Int, _: ProtocolSupport) throws -> Server) {
        self.select = select
    }

    public enum ServerSelectionError: Error, Equatable {
        case noLogical(LogicalResolutionFailureReason)
        case noEndpoints(EndpointResolutionFailureReason)

        public enum LogicalResolutionFailureReason: Equatable {
            case locationNotFound(ConnectionSpec.Location)
            case featuresNotSupported(Set<ConnectionSpec.Feature>)
            case protocolNotSupported(ProtocolSupport)
            case maintenance
        }

        public enum EndpointResolutionFailureReason: Equatable {
            case protocolNotSupported(ProtocolSupport)
            case maintenance
        }
    }
}

extension ServerSelector: TestDependencyKey {
    public static let testValue = ServerSelector(select: { spec, _, _ in
        throw ServerSelectionError.noLogical(.locationNotFound(spec.location))
    })
}

extension DependencyValues {
    public var serverSelector: ServerSelector {
        get { self[ServerSelector.self] }
        set { self[ServerSelector.self] = newValue }
    }
}
