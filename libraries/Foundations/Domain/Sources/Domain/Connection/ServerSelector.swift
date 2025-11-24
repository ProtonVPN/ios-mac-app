//
//  Created on 17/11/2025 by Chris Janusiewicz.
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
import Foundation

public struct ServerSelector: Sendable {
    public internal(set) var select: @Sendable (
        _ spec: ConnectionSpec,
        _ userTier: Int,
        _ acceptableProtocols: ProtocolSupport
    ) throws(SelectionError) -> Server

    public init(select: @escaping @Sendable (ConnectionSpec, Int, ProtocolSupport) throws(SelectionError) -> Server) {
        self.select = select
    }
}

public extension ServerSelector {
    enum SelectionError: ProtonVPNError, Equatable {
        case noLogical(LogicalResolutionFailureReason)
        case noEndpoints(EndpointResolutionFailureReason)

        public enum LogicalResolutionFailureReason: Equatable {
            case locationNotFound(ConnectionSpec.Location)
            case featuresNotSupported(Set<ConnectionSpec.Feature>)
            case protocolNotSupported(ProtocolSupport)
            case maintenance

            var charCode: FourCharCode {
                switch self {
                case .featuresNotSupported:
                    "LFNS"
                case .locationNotFound:
                    "LLNF"
                case .protocolNotSupported:
                    "LPNS"
                case .maintenance:
                    "LMNT"
                }
            }

            var userInfo: [String: Any] {
                switch self {
                case let .featuresNotSupported(features):
                    ["features": features]
                case let .locationNotFound(location):
                    ["location": location]
                case let .protocolNotSupported(unsupportedProtocol):
                    ["protocol": unsupportedProtocol]
                case .maintenance:
                    [:]
                }
            }
        }

        public enum EndpointResolutionFailureReason: Equatable {
            case protocolNotSupported(ProtocolSupport)
            case maintenance

            var charCode: FourCharCode {
                switch self {
                case .protocolNotSupported:
                    "EPNS"
                case .maintenance:
                    "EMNT"
                }
            }

            var userInfo: [String: Any] {
                switch self {
                case let .protocolNotSupported(unsupportedProtocol):
                    ["protocol": unsupportedProtocol]
                case .maintenance:
                    [:]
                }
            }
        }

        public var charCode: FourCharCode {
            switch self {
            case let .noEndpoints(reason):
                reason.charCode
            case let .noLogical(reason):
                reason.charCode
            }
        }

        public var extraUserInfo: [String: Any]? {
            switch self {
            case let .noEndpoints(reason):
                reason.userInfo
            case let .noLogical(reason):
                reason.userInfo
            }
        }
    }
}

extension ServerSelector: TestDependencyKey {
    public static let testValue = ServerSelector(
        select: { _, _, _ throws(SelectionError) in
            throw .noLogical(.maintenance)
        }
    )
}

public extension DependencyValues {
    var serverSelector: ServerSelector {
        get { self[ServerSelector.self] }
        set { self[ServerSelector.self] = newValue }
    }
}
