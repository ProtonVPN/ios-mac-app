//
//  Created on 17.05.23.
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

import SwiftUI
import Foundation

import Dependencies
import ComposableArchitecture

import Theme
import VPNShared

public struct HomeFeature: Reducer {
    /// - Note: might want this as a property of all Reducer types
    public typealias ActionSender = (Action) -> ()

    public struct State: Equatable {
        static let maxConnections = 8

        public var connections: [RecentConnection]

        public init(connections: [RecentConnection]) {
            self.connections = connections
        }

        mutating func trimConnections() {
            while connections.count > Self.maxConnections,
               let index = connections.lastIndex(where: \.notPinned) {
                connections.remove(at: index)
            }
        }
    }

    public enum Action: Equatable {
        /// Connect to a given connection specification. Bump it to the top of the
        /// list, if it isn't already pinned.
        case connect(ConnectionSpec)
        /// Pin a recent connection to the top of the list, and remove it from the recent connections.
        case pin(ConnectionSpec)
        /// Remove a connection from the pins, and add it to the top of the recent connections.
        case unpin(ConnectionSpec)
        /// Remove a connection.
        case remove(ConnectionSpec)
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            defer {
                state.trimConnections()
            }

            switch action {
            case let .connect(spec):
                var pinned = false

                if let index = state.connections.firstIndex(where: {
                    $0.connection == spec
                }) {
                    pinned = state.connections[index].pinned
                    state.connections.remove(at: index)
                }

                let recent = RecentConnection(
                    pinned: pinned,
                    underMaintenance: false,
                    connectionDate: .now,
                    connection: spec
                )
                state.connections.insert(recent, at: 0)
                return .none
            case let .pin(spec):
                guard let index = state.connections.firstIndex(where: {
                    $0.connection == spec
                }) else {
                    return .none
                }

                state.connections[index].pinned = true
                return .none
            case let .unpin(spec):
                guard let index = state.connections.firstIndex(where: {
                    $0.connection == spec
                }) else {
                    return .none
                }

                state.connections[index].pinned = false
                return .none
            case let .remove(spec):
                state.connections.removeAll {
                    $0.connection == spec
                }
                return .none
            }
        }
    }

    public init() {}
}

extension ConnectionSpec.Location {
    private func regionName(locale: Locale, code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    public func accessibilityText(locale: Locale) -> String {
        switch self {
        case .fastest:
            return "The fastest country available"
        case .secureCore(.fastest):
            return "The fastest secure core country available"
        default:
            // todo: .exact and .region should specify number and ideally features as well
            return text(locale: locale)
        }
    }

    public func text(locale: Locale) -> String {
        switch self {
        case .fastest,
                .secureCore(.fastest):
            return "Fastest"
        case .region(let code),
                .exact(_, _, _, let code),
                .secureCore(.fastestHop(let code)),
                .secureCore(.hop(let code, _)):
            return regionName(locale: locale, code: code)
        }
    }

    public func subtext(locale: Locale) -> String? {
        switch self {
        case .fastest, .region, .secureCore(.fastest), .secureCore(.fastestHop):
            return nil
        case let .exact(server, number, subregion, _):
            if server == .free {
                return "FREE#\(number)"
            } else if let subregion {
                return "\(subregion) #\(number)"
            } else {
                return nil
            }
        case .secureCore(.hop(_, let via)):
            return "via \(regionName(locale: locale, code: via))"
        }
    }


    public var flag: any FlagView {
        switch self {
        case .fastest:
            return FastestFlagView(secureCore: false)
        case .region(let code):
            return SimpleFlagView(regionCode: code)
        case .exact(_, _, _, let code):
            return SimpleFlagView(regionCode: code)
        case .secureCore(let secureCoreSpec):
            switch secureCoreSpec {
            case .fastest:
                return FastestFlagView(secureCore: true)
            case let .fastestHop(code):
                return SecureCoreFlagView(regionCode: code, viaRegionCode: nil)
            case let .hop(code, via):
                return SecureCoreFlagView(regionCode: code, viaRegionCode: via)
            }
        }
    }
}

extension RecentConnection {
    public var icon: Image {
        if pinned {
            return Theme.Asset.icPinFilled.swiftUIImage
        } else {
            return Theme.Asset.icClockRotateLeft.swiftUIImage
        }
    }
}

extension HomeFeature.State {
    public var mostRecent: RecentConnection? {
        connections.first
    }

    var remainingConnections: [RecentConnection] {
        guard connections.count > 1 else {
            return []
        }
        return Array(connections[1...])
    }

    public var remainingPinnedConnections: [RecentConnection] {
        remainingConnections.filter(\.pinned)
    }

    public var remainingRecentConnections: [RecentConnection] {
        remainingConnections.filter(\.notPinned)
    }
}

#if DEBUG
extension HomeFeature.State {
    public static let preview: Self = .init(connections: [
        .init(
            pinned: true,
            underMaintenance: false,
            connectionDate: .now,
            connection: .init(
                location: .fastest,
                features: []
            )
        ),
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now.addingTimeInterval(-2 * 60.0),
            connection: .init(
                location: .exact(
                    .free,
                    number: 42,
                    subregion: nil,
                    regionCode: "FR"
                ),
                features: []
            )
        ),
        .init(
            pinned: false,
            underMaintenance: true,
            connectionDate: .now.addingTimeInterval(-6 * 60.0),
            connection: .init(
                location: .secureCore(.hop(to: "US", via: "CH")),
                features: []
            )
        ),
        .init(
            pinned: true,
            underMaintenance: true,
            connectionDate: .now.addingTimeInterval(-8 * 60.0),
            connection: .init(
                location: .region(code: "UA"),
                features: [.streaming]
            )
        ),
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now.addingTimeInterval(-6 * 60 * 60.0),
            connection: .init(
                location: .secureCore(.fastestHop(to: "AR")),
                features: []
            )
        )
    ])
}
#endif
