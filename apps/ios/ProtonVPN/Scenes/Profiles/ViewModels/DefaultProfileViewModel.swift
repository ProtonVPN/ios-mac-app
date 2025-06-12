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

import UIKit
import Dependencies
import ProtonCoreUIFoundations
import LegacyCommon
import VPNAppCore
import Strings
import Theme
import ComposableArchitecture
import Combine
import Domain

import ProtonCoreFeatureFlags

/// Special case of `DefaultProfileViewModel`, used for free users, that have profiles disabled
/// but have this special `Fastest` connection type in countries list.
///
/// Differences:
/// - Doesn't check users tier for UI purposes
/// - Doesn't check `authorizer` during connection attempt
class FastestConnectionViewModel: DefaultProfileViewModel {
    override var isUsersTierTooLow: Bool { false }

    override func connectAction() {
        log.debug("Connect requested by selecting default profile in countries list.", category: .connectionConnect, event: .trigger)

        authorizedConnectAction()
    }
}

class DefaultProfileViewModel {
    @Dependency(\.profileAuthorizer) var authorizer
    private let alertService: AlertService

    private let serverOffering: ServerOffering
    private let vpnGateway: VpnGatewayProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let connectionStatusService: ConnectionStatusService
    private let netShieldPropertyProvider: NetShieldPropertyProvider
    private let natTypePropertyProvider: NATTypePropertyProvider
    private let safeModePropertyProvider: SafeModePropertyProvider

    private let defaultAccessTier: Int

    private var profile: Profile {
        switch serverOffering {
        case .random:
            return Profile(id: "st_r",
                           accessTier: defaultAccessTier,
                           profileIcon: .arrowsSwapRight,
                           profileType: .system,
                           serverType: propertiesManager.serverTypeToggle,
                           serverOffering: serverOffering,
                           name: Localizable.random,
                           connectionProtocol: propertiesManager.connectionProtocol)
        default:
            return Profile(id: "st_f",
                           accessTier: defaultAccessTier,
                           profileIcon: .bolt,
                           profileType: .system,
                           serverType: propertiesManager.serverTypeToggle,
                           serverOffering: serverOffering,
                           name: Localizable.fastest,
                           connectionProtocol: propertiesManager.connectionProtocol)
        }
    }

    private let isRedesign: Bool
    private let extraMargin: Bool

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

    var isConnected: Bool {
        guard FeatureFlagsRepository.isConnectionFeatureEnabled else {
            guard vpnGateway.connection == .connected else { return false }

            return vpnGateway.lastConnectionRequest == profile.connectionRequest(
                withDefaultNetshield: netShieldPropertyProvider.netShieldType,
                withDefaultNATType: natTypePropertyProvider.natType,
                withDefaultSafeMode: safeModePropertyProvider.safeMode,
                trigger: .profile
            )
        }

        guard case .connected = vpnConnectionStatus else {
            return false
        }

        return propertiesManager.lastConnectionIntent == ConnectionSpec(
            connectionRequest: profile.connectionRequest(
                withDefaultNetshield: netShieldPropertyProvider.netShieldType,
                withDefaultNATType: natTypePropertyProvider.natType,
                withDefaultSafeMode: safeModePropertyProvider.safeMode,
                trigger: .profile
            )
        )
    }

    var isConnecting: Bool {
        guard FeatureFlagsRepository.isConnectionFeatureEnabled else {
            guard vpnGateway.connection == .connecting else { return false }

            return vpnGateway.lastConnectionRequest == profile.connectionRequest(
                withDefaultNetshield: netShieldPropertyProvider.netShieldType,
                withDefaultNATType: natTypePropertyProvider.natType,
                withDefaultSafeMode: safeModePropertyProvider.safeMode,
                trigger: .profile
            )
        }

        guard case let .connecting(connectionSpec, _) = vpnConnectionStatus else {
            return false
        }

        return connectionSpec == ConnectionSpec(
            connectionRequest: profile.connectionRequest(
                withDefaultNetshield: netShieldPropertyProvider.netShieldType,
                withDefaultNATType: natTypePropertyProvider.natType,
                withDefaultSafeMode: safeModePropertyProvider.safeMode,
                trigger: .profile
            )
        )
    }

    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }

    fileprivate var isUsersTierTooLow: Bool {
        return !authorizer.canUseProfile(ofTier: defaultAccessTier)
    }

    var connectionChanged: (() -> Void)?

    var connectIcon: UIImage? = IconProvider.powerOff

    var title: String {
        switch serverOffering {
        case .fastest:
            return Localizable.fastestConnection
        case .random:
            return Localizable.randomConnection
        default:
            return ""
        }
    }

    var image: UIImage {
        switch serverOffering {
        case .fastest:
            return isRedesign ? Asset.fastest.image : IconProvider.bolt
        case .random:
            return IconProvider.arrowsSwapRight
        default:
            return UIImage()
        }
    }

    var imageInPlaceOfConnectIcon: UIImage? {
        return isUsersTierTooLow ? Theme.Asset.vpnSubscriptionBadge.image : nil
    }

    var alphaOfMainElements: CGFloat {
        return isUsersTierTooLow ? 0.5 : 1.0
    }

    var connectButtonMargin: CGFloat {
        return extraMargin ? 32 : 0
    }

    init(serverOffering: ServerOffering, vpnGateway: VpnGatewayProtocol, alertService: AlertService, propertiesManager: PropertiesManagerProtocol, connectionStatusService: ConnectionStatusService, netShieldPropertyProvider: NetShieldPropertyProvider, natTypePropertyProvider: NATTypePropertyProvider, safeModePropertyProvider: SafeModePropertyProvider, isRedesign: Bool = false, extraMargin: Bool = false) {
        self.serverOffering = serverOffering
        self.propertiesManager = propertiesManager
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.connectionStatusService = connectionStatusService
        self.netShieldPropertyProvider = netShieldPropertyProvider
        self.natTypePropertyProvider = natTypePropertyProvider
        self.safeModePropertyProvider = safeModePropertyProvider
        self.defaultAccessTier = .paidTier
        self.isRedesign = isRedesign
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
            vpnGateway.stopConnecting(userInitiated: true)
        } else if isConnected {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.disconnect(.profile))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            log.debug("Will connect to \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(profile: profile)
            connectionStatusService.presentStatusViewController()
        }
    }

    // MARK: - Private functions

    private var cancellables = Set<AnyCancellable>()

    private func startObserving() {
        guard FeatureFlagsRepository.isConnectionFeatureEnabled else {
            AppEvent.connectionStateChanged.subscribe(self, selector: #selector(stateChanged))
            return
        }

        $vpnConnectionStatus
            .publisher
            .sink { [weak self] _ in
                self?.stateChanged()
            }
            .store(in: &cancellables)
    }

    @objc private func stateChanged() {
        if let connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}
