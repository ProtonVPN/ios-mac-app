//
//  Created on 07/10/2024.
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

import Domain
import ComposableArchitecture
import Foundation
import VPNAppCore
import VPNShared
import OrderedCollections
import SwiftUI
import Ergonomics

@Reducer
public struct RecentsFeature {
    public typealias ActionSender = (Action) -> Void

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.vpnConnectionStatus)
        public var vpnConnectionStatus: VPNConnectionStatus

        @SharedReader(.defaultConnectionPreference)
        private var defaultConnectionPreference
        @Shared(.recents)
        public var recents: OrderedSet<RecentConnection>

        // VPNAPPL- : Move this and other recents logic (defined in OrderedSet extension) to a client/dependency
        public var recentConnectionList: OrderedSet<RecentConnection> {
            return recents
            // The below is not correct and needs fixing
//            switch defaultConnectionPreference {
//            case .mostRecent:
//                // We are already showing the most recent connection in the connection card
//                return recents.connectionsList // without most recent connection, unless it's pinned
//            case .recent(let spec):
//                return recents.filter { $0.connection != spec || $0.pinned }
//            case .fastest:
//                return recents.filter { $0.connection != .defaultFastest || $0.pinned }
//            }
        }

        @SharedReader(.userTier)
        public var userTier: Int

        public init() {
            @Dependency(\.recentsStorage) var recentsStorage
            $recents |=| recentsStorage.readFromStorage()
        }
    }

    @CasePathable
    public enum Action {
        case connectionEstablished(ConnectionSpec)
        case pin(RecentConnection)
        case unpin(RecentConnection)
        case remove(RecentConnection)
        case watchConnectionStatus
        case newConnectionStatus(VPNConnectionStatus)
        case upsellTapped(BannerType)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case connect(ConnectionSpec)
        }
    }

    private enum CancelId {
        case watchConnectionStatus
    }

    @Dependency(\.recentsStorage) var recentsStorage
    @Dependency(\.date) var date
    @Dependency(\.pushAlert) var pushAlert

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .watchConnectionStatus:
                return .publisher {
                    state
                        .$vpnConnectionStatus
                        .publisher
                        .removeDuplicates()
                        .receive(on: UIScheduler.shared)
                        .map(Action.newConnectionStatus)
                }
                .cancellable(id: CancelId.watchConnectionStatus)

            case .upsellTapped(let type):
                switch type {
                case .worldwideCover:
                    pushAlert(AllCountriesUpsellAlert())
                case .fasterBrowsing:
                    pushAlert(VPNAcceleratorUpsellAlert())
                case .streaming:
                    pushAlert(StreamingUpsellAlert())
                case .netshield:
                    pushAlert(NetShieldUpsellAlert())
                case .secureCore:
                    pushAlert(SecureCoreUpsellAlert())
                case .p2p:
                    pushAlert(P2PUpsellAlert())
                case .devices:
                    pushAlert(DevicesUpsellAlert())
                case .tor:
                    pushAlert(TorUpsellAlert())
                case .more:
                    pushAlert(CustomizationUpsellAlert())
                }

                return .none

            case .newConnectionStatus(let connectionStatus):
                guard case .connected = connectionStatus else { return .none }
                guard let spec = connectionStatus.spec else {
                    log.info("Unable to generate spec for connection status: \(connectionStatus)")
                    return .none
                }
                return .send(.connectionEstablished(spec))

            case .connectionEstablished(let spec):
                guard spec.shouldManifestRecentsEntry else {
                    log.debug("Ignoring entry to recents list for spec", metadata: ["spec": "\(spec)"])
                    return .none
                }
                withAnimation {
                    state.$recents.withLock { $0.updateList(with: spec) }
                }
                recentsStorage.saveToStorage(state.recents)

                return .none

            case let .pin(recent):
                withAnimation {
                    state.$recents.withLock { $0.pin(recent: recent, pinnedDate: date.now) }
                }
                recentsStorage.saveToStorage(state.recents)
                return .none

            case let .unpin(recent):
                withAnimation {
                    state.$recents.withLock { $0.unpin(recent: recent) }
                }
                recentsStorage.saveToStorage(state.recents)
                return .none

            case let .remove(recent):
                withAnimation {
                    state.$recents.withLock { $0.remove(recent) }
                }
                recentsStorage.saveToStorage(state.recents)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

extension ConnectionSpec {
    public var shouldManifestRecentsEntry: Bool {
        // We don't want the change server action to add a `Random` item into recents
        location != .random
    }
}
