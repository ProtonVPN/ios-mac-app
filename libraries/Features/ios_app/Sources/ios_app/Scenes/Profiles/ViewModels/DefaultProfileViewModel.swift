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
import Dependencies
import Domain
import LegacyCommon
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
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
    @Dependency(\.connectToVPN) private var connectToVPN
    @Dependency(\.disconnectVPN) private var disconnectVPN
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.safeModePropertyProvider) private var safeModePropertyProvider
    @Dependency(\.natTypePropertyProvider) private var natTypePropertyProvider
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    private let alertService: AlertService

    private let serverOffering: ServerOffering
    @Dependency(\.propertiesManager) private var propertiesManager
    private let connectionStatusService: ConnectionStatusService

    private let defaultAccessTier: Int

    private var profile: Profile {
        switch serverOffering {
        case .random:
            Profile(
                id: "st_r",
                accessTier: defaultAccessTier,
                profileIcon: .arrowsSwapRight,
                profileType: .system,
                serverType: propertiesManager.serverTypeToggle,
                serverOffering: serverOffering,
                name: Localizable.random,
                connectionProtocol: propertiesManager.connectionProtocol
            )
        default:
            Profile(
                id: "st_f",
                accessTier: defaultAccessTier,
                profileIcon: .bolt,
                profileType: .system,
                serverType: propertiesManager.serverTypeToggle,
                serverOffering: serverOffering,
                name: Localizable.fastest,
                connectionProtocol: propertiesManager.connectionProtocol
            )
        }
    }

    private let extraMargin: Bool

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

    var isConnected: Bool {
        guard case .connected = vpnConnectionStatus else {
            return false
        }

        return propertiesManager.lastConnectionIntent == profileConnectionSpec
    }

    var isConnecting: Bool {
        guard case let .connecting(connectionSpec, _) = vpnConnectionStatus else {
            return false
        }

        return connectionSpec == profileConnectionSpec
    }

    private var connectedUiState: Bool {
        isConnected || isConnecting
    }

    fileprivate var isUsersTierTooLow: Bool {
        !authorizer.canUseProfile(ofTier: defaultAccessTier)
    }

    var connectionChanged: (() -> Void)?

    var connectIcon: UIImage? = IconProvider.powerOff

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
            Asset.fastest.image
        case .random:
            IconProvider.arrowsSwapRight
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
        alertService: AlertService,
        connectionStatusService: ConnectionStatusService,
        extraMargin: Bool = false
    ) {
        self.serverOffering = serverOffering
        self.alertService = alertService
        self.connectionStatusService = connectionStatusService
        self.defaultAccessTier = .paidTier
        self.extraMargin = extraMargin
        startObserving()
    }

    func connectAction() {
        log.debug("Connect requested by selecting default profile.", category: .connectionConnect, event: .trigger)

        guard authorizer.canUseProfiles else {
            log.debug("Connect to profile rejected because user is on free plan", category: .connectionConnect, event: .trigger)
            alertService.push(alert: ProfilesUpsellAlert())
            return
        }
        authorizedConnectAction()
    }

    fileprivate func authorizedConnectAction() {
        if isConnecting {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            Task {
                try? await disconnectVPN(.profile)
            }
        } else if isConnected {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.disconnect(.profile))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            Task {
                try? await disconnectVPN(.profile)
            }
        } else {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            log.debug("Will connect to \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            connectionStatusService.presentStatusViewController()
            Task {
                do {
                    try await connectToVPN(profileConnectionSpec, profile.connectionProtocol, .profile)
                } catch {
                    log.error("Connect failed for default profile", category: .connectionConnect, metadata: ["error": "\(error)"])
                }
            }
        }
    }

    // MARK: - Private functions

    private var cancellables = Set<AnyCancellable>()

    private var profileConnectionSpec: ConnectionSpec {
        ConnectionSpec(
            connectionRequest: profile.connectionRequest(
                withDefaultNetshield: netShieldPropertyProvider.getNetShieldType(),
                withDefaultNATType: natTypePropertyProvider.getNATType(),
                withDefaultSafeMode: safeModePropertyProvider.getSafeMode(),
                withDefaultPortForwarding: portForwardingPropertyProvider.getPortForwarding(),
                trigger: .profile
            )
        )
    }

    private func startObserving() {
        $vpnConnectionStatus
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
            alertService: CoreAlertServiceDummy(),
            connectionStatusService: ConnectionStatusServiceMock()
        )

        static var fastestMock = DefaultProfileViewModel(
            serverOffering: .fastest("Server"),
            alertService: CoreAlertServiceDummy(),
            connectionStatusService: ConnectionStatusServiceMock()
        )

        static var randomMock = DefaultProfileViewModel(
            serverOffering: .random("Server"),
            alertService: CoreAlertServiceDummy(),
            connectionStatusService: ConnectionStatusServiceMock()
        )

        static var withExtraMarginMock = DefaultProfileViewModel(
            serverOffering: .fastest("Server"),
            alertService: CoreAlertServiceDummy(),
            connectionStatusService: ConnectionStatusServiceMock(),
            extraMargin: true
        )

        static var connectedMock: DefaultProfileViewModel = {
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus
            $vpnConnectionStatus.withLock { $0 = .connected(.defaultFastest, nil) }
            return DefaultProfileViewModel(
                serverOffering: .fastest("Server"),
                alertService: CoreAlertServiceDummy(),
                connectionStatusService: ConnectionStatusServiceMock()
            )
        }()

        static var connectingMock: DefaultProfileViewModel = {
            @Shared(.vpnConnectionStatus) var vpnConnectionStatus
            $vpnConnectionStatus.withLock { $0 = .connecting(.defaultFastest, nil) }
            return DefaultProfileViewModel(
                serverOffering: .fastest("Server"),
                alertService: CoreAlertServiceDummy(),
                connectionStatusService: ConnectionStatusServiceMock()
            )
        }()
    }

    private class ConnectionStatusServiceMock: ConnectionStatusService {
        func presentStatusViewController() {}
    }
#endif
