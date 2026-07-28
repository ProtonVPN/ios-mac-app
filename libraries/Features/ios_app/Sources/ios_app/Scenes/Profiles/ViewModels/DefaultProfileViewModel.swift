//
//  DefaultProfileViewModel.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Combine
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import LegacyCommon
import Strings
import Theme
import UIKit
import VPNAppCore

/// Special case of `DefaultProfileViewModel`, used for free users, that have profiles disabled
/// but have this special `Fastest` connection type in countries list.
///
/// Differences:
/// - Doesn't check users tier for UI purposes
/// - Doesn't check `authorizer` during connection attempt
class FastestConnectionViewModel: DefaultProfileViewModel {
    override var isUsersTierTooLow: Bool {
        false
    }

    override func connectAction() {
        log.debug("Connect requested by selecting default profile in countries list.", category: .connectionConnect, event: .trigger)

        authorizedConnectAction()
    }
}

class DefaultProfileViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    @Dependency(\.connectionCommandClient) private var connectionCommandClient

    @Dependency(\.upsellManager) private var upsellManager

    private let serverOffering: ServerOffering
    private let connectionStatusService: ConnectionStatusService

    private let defaultAccessTier: VpnTier

    private var profile: Profile {
        @SharedReader(.connectionProtocol) var connectionProtocol
        switch serverOffering {
        case .random:
            return Profile(
                id: "st_r",
                accessTier: defaultAccessTier,
                profileIcon: .arrowsSwapRight,
                profileType: .system,
                serverType: ServerType.current,
                serverOffering: serverOffering,
                name: Localizable.random,
                connectionProtocol: connectionProtocol
            )
        default:
            return Profile(
                id: "st_f",
                accessTier: defaultAccessTier,
                profileIcon: .bolt,
                profileType: .system,
                serverType: ServerType.current,
                serverOffering: serverOffering,
                name: Localizable.fastest,
                connectionProtocol: connectionProtocol
            )
        }
    }

    private let extraMargin: Bool

    @SharedReader(.connectionState) var connectionState: ConnectionState

    var isConnected: Bool {
        guard connectionState.is(\.connected), let spec = connectionState.resolvedSpec else {
            return false
        }
        return spec == profileConnectionSpec
    }

    var isConnecting: Bool {
        guard connectionState.is(\.connecting), let spec = connectionState.resolvedSpec else {
            return false
        }

        return spec == profileConnectionSpec
    }

    private var connectedUiState: Bool {
        isConnected || isConnecting
    }

    fileprivate var isUsersTierTooLow: Bool {
        !authorizer.canUseProfile(ofTier: defaultAccessTier)
    }

    var connectionChanged: (() -> Void)?

    var connectIcon: UIImage = Theme.Asset.Icons.powerOff.image

    var title: String {
        switch serverOffering {
        case .fastest:
            Localizable.fastestConnection
        case .random:
            Localizable.randomConnection
        default:
            ""
        }
    }

    var image: UIImage {
        switch serverOffering {
        case .fastest:
            UIImage(resource: .fastest)
        case .random:
            Theme.Asset.Icons.arrowsSwapRight.image
        default:
            UIImage()
        }
    }

    var imageInPlaceOfConnectIcon: UIImage? {
        isUsersTierTooLow ? Theme.Asset.vpnSubscriptionBadge.image : nil
    }

    var alphaOfMainElements: CGFloat {
        isUsersTierTooLow ? 0.5 : 1.0
    }

    var connectButtonMargin: CGFloat {
        extraMargin ? 32 : 0
    }

    init(
        serverOffering: ServerOffering,
        connectionStatusService: ConnectionStatusService,
        extraMargin: Bool = false
    ) {
        self.serverOffering = serverOffering
        self.connectionStatusService = connectionStatusService
        self.defaultAccessTier = .paid
        self.extraMargin = extraMargin
        startObserving()
    }

    func connectAction() {
        log.debug("Connect requested by selecting default profile.", category: .connectionConnect, event: .trigger)

        guard authorizer.canUseProfiles else {
            log.debug("Connect to profile rejected because user is on free plan", category: .connectionConnect, event: .trigger)
            upsellManager.present(.profiles)
            return
        }
        authorizedConnectAction()
    }

    fileprivate func authorizedConnectAction() {
        if isConnecting {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            connectionCommandClient.send(.disconnect(.profile))
        } else if isConnected {
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            connectionCommandClient.send(.disconnect(.profile))
        } else {
            log.debug("Will connect to \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            connectionStatusService.presentHome()
            connectionCommandClient.send(.connect(profileConnectionSpec, profile.connectionProtocol, .profile))
        }
    }

    // MARK: - Private functions

    private var cancellables = Set<AnyCancellable>()

    private var profileConnectionSpec: ConnectionSpec {
        profile.connectionSpec(trigger: .profile)
    }

    private func startObserving() {
        $connectionState
            .publisher
            .sink { [weak self] _ in
                self?.stateChanged()
            }
            .store(in: &cancellables)
    }

    @objc
    private func stateChanged() {
        if let connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}

#if DEBUG
    extension DefaultProfileViewModel {
        static var mock = DefaultProfileViewModel(
            serverOffering: .fastest("Server"),
            connectionStatusService: ConnectionStatusServiceMock()
        )

        static var fastestMock = DefaultProfileViewModel(
            serverOffering: .fastest("Server"),
            connectionStatusService: ConnectionStatusServiceMock()
        )

        static var randomMock = DefaultProfileViewModel(
            serverOffering: .random("Server"),
            connectionStatusService: ConnectionStatusServiceMock()
        )

        static var withExtraMarginMock = DefaultProfileViewModel(
            serverOffering: .fastest("Server"),
            connectionStatusService: ConnectionStatusServiceMock(),
            extraMargin: true
        )

        static var connectedMock: DefaultProfileViewModel {
            @Shared(.connectionState) var connectionState
            $connectionState.withLock { $0 = .previewConnected(for: .defaultFastest) }
            return DefaultProfileViewModel(
                serverOffering: .fastest("Server"),
                connectionStatusService: ConnectionStatusServiceMock()
            )
        }

        static var connectingMock: DefaultProfileViewModel {
            @Shared(.connectionState) var connectionState
            $connectionState.withLock { $0 = .previewConnecting(for: .defaultFastest) }
            return DefaultProfileViewModel(
                serverOffering: .fastest("Server"),
                connectionStatusService: ConnectionStatusServiceMock()
            )
        }
    }

    private class ConnectionStatusServiceMock: ConnectionStatusService {
        func presentHome() {}
    }
#endif
