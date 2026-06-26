//
//  SettingsViewModel.swift
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
import CommonNetworking
import Connection
import Dependencies
import Domain
import Ergonomics
import ExtensionManager
import LegacyCommon
import LocalAuthentication
import Modals
import ProtonCoreAccountRecovery
import ProtonCoreDataModel
import ProtonCoreFeatureFlags
import ProtonCoreLoginUI
import ProtonCoreUIFoundations
import Settings
import Sharing
import Strings
import SwiftUI
import UIKit
import VPNAppCore
import VPNShared

// TODO: Migrate to @MainActor once overall codebase is ready for it

final class SettingsViewModel {
    typealias Factory =
        AppSessionManagerFactory &
        ConnectionStatusServiceFactory &
        CoreAlertServiceFactory &
        NavigationServiceFactory &
        ProfileManagerFactory &
        SettingsServiceFactory

    private let factory: Factory

    @Dependency(\.propertiesManager) private var propertiesManager
    @Shared(.connectionState) private var connectionState: ConnectionState
    @Shared(.featureFlags) private var featureFlags: Domain.FeatureFlags
    @Shared(.connectionProtocol) private var sharedConnectionProtocol: Domain.ConnectionProtocol
    @Shared(.killSwitch) private var killSwitch: Bool
    @Shared(.sessionStatus) private var sessionStatus: SessionStatus
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var alertService: AlertService = factory.makeCoreAlertService()
    @Dependency(\.upsellManager) private var upsellManager
    private lazy var settingsService: SettingsService = factory.makeSettingsService()
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private lazy var connectionStatusService: ConnectionStatusService = factory.makeConnectionStatusService()
    @Dependency(\.natTypePropertyProvider) private var natTypePropertyProvider
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider

    @SharedReader(.appliedFeatures) private var appliedFeatures: AgentTunnelFeatures?
    private lazy var navigationService: NavigationService = factory.makeNavigationService()
    @Dependency(\.appInfo) private var appInfo
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.networking) private var networking
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    private let protocolService: ProtocolService
    private var cancellables = Set<AnyCancellable>()

    /// The different in-flight settings waiting to be confirmed by the LocalAgent.
    private enum AgentToggle { case nat, vpnAccelerator }
    private var applyingToggles: Set<AgentToggle> = []
    private var applyingTimeouts: [AgentToggle: Task<Void, Never>] = [:]

    private static let applyingTimeout: Duration = .seconds(3)

    var reloadNeeded: (() -> Void)?

    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.featureAuthorizerProvider) private var featureAuthorizerProvider
    lazy var netShieldTypeAuthorizer = featureAuthorizerProvider.authorizer(forSubFeatureOf: NetShieldType.self)

    @Dependency(\.hermesClient) private var hermesClient

    private var profileManager: ProfileManager?
    private var accountRecoveryRepository: AccountRecoveryRepositoryProtocol?
    private let isAccountRecoveryEnabled: Bool

    var pushHandler: ((_ viewController: UIViewController, _ translucentNavBar: Bool, _ hidesBackBarButton: Bool) -> Void)?
    var showModalController: ((UIViewController) -> Void)?

    private let hermesSettingsViewModel: HermesSettingsViewModel

    // MARK: - Init

    init(factory: Factory, protocolService: ProtocolService) {
        self.factory = factory
        self.protocolService = protocolService

        self.hermesSettingsViewModel = HermesSettingsViewModel()

        self.isAccountRecoveryEnabled = AccountRecoveryModule.feature.enabled

        if sessionStatus == .established {
            sessionEstablished()
        }

        if isAccountRecoveryEnabled {
            self.accountRecoveryRepository = AccountRecoveryRepository(apiService: networking.apiService)
        }

        startObserving()
        observeAppliedFeatures()
    }

    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = []

        sections.append(accountSection)
        sections.append(securitySection)
        sections.append(advancedSection)

        if let connectionSection {
            sections.append(connectionSection)
        }

        sections.append(extensionsSection)
        sections.append(usageStatisticsSection)
        sections.append(logSection)
        sections.append(bottomSection)

        return sections
    }

    var shouldShowAccountRecovery: Bool {
        accountRecoveryStatus?.isVisibleInSettings ?? false
    }

    var accountRecoveryStateText: String {
        accountRecoveryStatus?.valueForSettingsItem ?? ""
    }

    var accountRecoveryImage: UIImage? {
        accountRecoveryStatus?.imageForSettingsItem
    }

    // MARK: - Action handling

    private func push(
        viewController: UIViewController,
        hidesTranslucentNarBar: Bool = false,
        hidesBackBarButton: Bool = false
    ) {
        pushHandler?(viewController, hidesTranslucentNarBar, hidesBackBarButton)
    }

    // MARK: - Header section

    func viewForFooter() -> UIView {
        let view = AppVersionView()
        view.setVersionText(Localizable.version + " \(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))")
        return view
    }

    // MARK: - Private functions

    private func startObserving() {
        $sessionStatus
            .publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.sessionChanged(status)
            }
            .store(in: &cancellables)

        let reloadEvents: [AppEvent] = [
            .sessionManagerDataReloaded,
            .credentialsChanged,
        ]
        reloadEvents.subscribe(self, selector: #selector(reload))

        $featureFlags
            .publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)

        $sharedConnectionProtocol
            .publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)

        $connectionState
            .publisher
            .sink { [weak self] _ in
                self?.reloadNeeded?()
            }
            .store(in: &cancellables)
    }

    private func sessionChanged(_ status: SessionStatus) {
        if status == .established {
            sessionEstablished()
        } else {
            sessionEnded()
        }

        reloadNeeded?()
    }

    private func sessionEstablished() {
        profileManager = factory.makeProfileManager()

        let reloadEvents: [AppEvent] = [
            .profileContentChanged,
        ]

        reloadEvents.subscribe(self, selector: #selector(reload))
    }

    private func sessionEnded() {
        if profileManager != nil {
            AppEvent.profileContentChanged.unsubscribe(self)
        }

        profileManager = nil
    }

    @objc
    private func reload() {
        reloadNeeded?()
    }

    private var accountSection: TableViewSection {
        @Dependency(\.credentiallessHelper) var credentiallessHelper
        let userIsCredentialLess = credentiallessHelper.isCredentialLess()
        guard !userIsCredentialLess else {
            let handler: (NewAccountCardView.Action) -> Void = { [weak self] action in
                let presentScreen: (NewAccountCardView.Action) -> Void = { [weak self] action in
                    switch action {
                    case .signUp: self?.presentSignUpScreen()
                    case .signIn: self?.presentSignInScreen()
                    }
                }

                // Check if we are connected. Changing the user's session means we will need to reconnect them.
                // Let the user know they will be disconnected if they proceed
                @Shared(.connectionState) var connectionState
                let isDisconnected = connectionState.is(\.disconnected)

                if isDisconnected {
                    presentScreen(action)
                } else {
                    let reconnectionAlert = DisconnectToSignInAlert(
                        continueHandler: {
                            @Dependency(\.connectionCommandClient) var connectionCommandClient
                            connectionCommandClient.send(.disconnect(.signout, completion: { @MainActor in
                                presentScreen(action)
                            }))
                        },
                        cancelHandler: { log.debug("User cancelled sign in/sign up", category: .settings) }
                    )
                    self?.alertService.push(alert: reconnectionAlert)
                }
            }
            let newAccountCardCell = TableViewCellModel.newAccountCard(handler: handler)
            return TableViewSection(title: Localizable.account, cells: [newAccountCardCell])
        }

        let username: String = authKeychain.username ?? Localizable.unavailable
        let accountPlanName: String = if let vpnCredentials = try? vpnKeychain.fetchCached() {
            vpnCredentials.planTitle
        } else {
            Localizable.unavailable
        }

        let cell = TableViewCellModel.pushAccountDetails(
            initials: NSAttributedString(string: username.initials(), attributes: .CaptionStrong),
            username: NSAttributedString(string: username, attributes: .DefaultSmall),
            plan: NSAttributedString(string: accountPlanName, attributes: .CaptionWeak)
        ) { [weak self] in
            self?.pushSettingsAccountViewController()
        }

        var cells: [TableViewCellModel]
        if isAccountRecoveryEnabled, shouldShowAccountRecovery {
            let accountRecoveryCell = TableViewCellModel.pushKeyValue(key: AccountRecoveryModule.settingsItem, value: accountRecoveryStateText, icon: accountRecoveryImage) { [weak self] in
                self?.pushAccountRecoveryViewController()
            }
            cells = [cell, accountRecoveryCell]
        } else {
            cells = [cell]
        }

        let qrLoginOptedOut = propertiesManager.userInfo?.edmOptOut == 1
        let qrLoginFeatureDisabled = CoreFeatureFlagType.easyDeviceMigrationDisabled.enabled
        let isDeviceSecured: Bool = {
            #if targetEnvironment(simulator)
                return true
            #else
                return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            #endif
        }()

        if !qrLoginFeatureDisabled, !qrLoginOptedOut, isDeviceSecured {
            let qrCodeSignInCell = TableViewCellModel.pushStandard(title: Localizable.settingsTitleQrCodeSignIn) { [weak self] in
                self?.pushSignInToAnotherDeviceViewController()
            }

            cells.append(qrCodeSignInCell)
        }

        let links = ExternalLinks(clientApp: .vpn)
        cells.append(.markdownTooltip(
            "[\(Localizable.termsAndConditions)](\(links.termsAndConditions)) ・ " +
                "[\(Localizable.privacyPolicy)](\(links.privacyPolicy))",
            align: .center
        ))

        return TableViewSection(title: Localizable.account, cells: cells)
    }

    private var accountRecoveryStatus: AccountRecovery? {
        propertiesManager.userAccountRecovery
    }

    private var securitySection: TableViewSection {
        var cells: [TableViewCellModel] = []

        let protocolValue: String = switch sharedConnectionProtocol {
        case .smartProtocol:
            Localizable.smartTitle
        case let .vpnProtocol(vpnProtocol):
            vpnProtocol.localizedDescription
        }
        cells.append(.pushKeyValue(key: Localizable.protocol, value: protocolValue, handler: { [weak self] in
            self?.pushProtocolViewController()
        }))

        cells.append(.tooltip(text: Localizable.smartProtocolDescription))

        cells.append(contentsOf: netShieldCells)

        cells.append(.upsellableToggle(
            title: Localizable.alwaysOnVpn,
            state: { .available(enabled: true, interactive: false) },
            upsell: {}, // Always on VPN is always in the enabled and non-interactive state
            handler: nil
        ))
        cells.append(.tooltip(text: Localizable.alwaysOnVpnTooltipIos))

        cells.append(.upsellableToggle(
            title: Localizable.killSwitch,
            state: { [unowned self] in .available(enabled: killSwitch, interactive: true) },
            upsell: {
                // No Upsell: Kill Switch is a free feature
            },
            handler: ksSwitchCallback()
        ))
        cells.append(.tooltip(text: Localizable.killSwitchTooltip))

        return TableViewSection(title: Localizable.securityOptions, cells: cells)
    }

    private var netShieldCells: [TableViewCellModel] {
        let canUse: () -> FeatureAuthorizationResult = featureAuthorizerProvider.authorizer(for: NetShieldType.self)
        switch canUse() {
        case .success:
            return [
                .pushKeyValue(
                    key: Localizable.netshieldTitle,
                    value: netShieldPropertyProvider.getNetShieldType().name,
                    handler: { [weak self] in self?.pushNetshieldSelectionViewController() }
                ),
                .tooltip(text: Localizable.netshieldTitleTooltip),
            ]
        case .failure(.requiresUpgrade):
            return [
                .upsellableToggle(
                    title: Localizable.netshieldTitle,
                    state: { .upsell },
                    upsell: { [weak self] in self?.upsellManager.present(.netShield) },
                    handler: { _, _ in }
                ),
                .tooltip(text: Localizable.netshieldTitleTooltip),
            ]
        case .failure(.featureDisabled):
            return []
        }
    }

    /// Only non-nil when the server reports a different value.
    private var appliedNATOverride: Bool? {
        guard case .connected = connectionState, let applied = appliedFeatures?.natType else { return nil }
        guard applied != natTypePropertyProvider.getNATType() else { return nil }

        // The toggle is set to "on" when moderate NAT is enabled. Otherwise, a "false" value indicates strict NAT.
        return applied == .moderateNAT
    }

    private var appliedVPNAcceleratorOverride: Bool? {
        guard case .connected = connectionState, let applied = appliedFeatures?.vpnAccelerator else { return nil }
        guard applied != (AuthorizedFeatureValue<VPNAccelerator>().value() == .on) else { return nil }
        return applied
    }

    /// Reloads the toggle rows whenever the applied features change to show/hide any progress spinners.
    private func observeAppliedFeatures() {
        $appliedFeatures.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clearConfirmedApplyingToggles() }
            .store(in: &cancellables)
    }

    private func markApplying(_ toggle: AgentToggle) {
        applyingToggles.insert(toggle)
        applyingTimeouts[toggle]?.cancel()
        applyingTimeouts[toggle] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.applyingTimeout)
            guard !Task.isCancelled else { return }
            self?.clearApplying(toggle)
        }
        reloadNeeded?()
    }

    private func clearApplying(_ toggle: AgentToggle) {
        applyingTimeouts[toggle]?.cancel()
        applyingTimeouts[toggle] = nil
        guard applyingToggles.remove(toggle) != nil else { return }
        reloadNeeded?()
    }

    /// Clears any applying toggle whose applied value now matches what the user requested (confirmed by LocalAgent).
    private func clearConfirmedApplyingToggles() {
        guard let applied = appliedFeatures else { return }
        let confirmed = applyingToggles.filter { toggle in
            switch toggle {
            case .nat: applied.natType == natTypePropertyProvider.getNATType()
            case .vpnAccelerator: applied.vpnAccelerator == (AuthorizedFeatureValue<VPNAccelerator>().value() == .on)
            }
        }
        confirmed.forEach { clearApplying($0) }
    }

    private var vpnAcceleratorSection: [TableViewCellModel] {
        [
            .upsellableToggle(
                title: Localizable.vpnAcceleratorTitle,
                overriddenValue: appliedVPNAcceleratorOverride,
                isPending: applyingToggles.contains(.vpnAccelerator),
                state: { [unowned self] in displayState(for: VPNAccelerator.self) },
                upsell: { [weak self] in self?.upsellManager.present(.vpnAccelerator) },
                handler: { toggleOn, callback in
                    self.getFeatureChangeAvailability(for: .agent(.vpnAccelerator(toggleOn))) { featureChangeAvailability in
                        let acceleratorValue = toggleOn ? VPNAccelerator.on : VPNAccelerator.off
                        switch featureChangeAvailability {
                        case .withReconnect:
                            // We don't support any non cert-auth protocols on iOS.
                            log.assertionFailure("VPNAccelerator should never require a reconnect on iOS")
                            fallthrough
                        case .withConnectionUpdate:
                            setFeatureValue(acceleratorValue)
                            self.apply(agentFeatureChange: .vpnAccelerator(toggleOn))
                            callback(toggleOn)
                            self.markApplying(.vpnAccelerator)
                        case .immediate:
                            setFeatureValue(toggleOn ? VPNAccelerator.on : VPNAccelerator.off)
                            callback(toggleOn)
                        }
                    }
                }
            ),
            .attributedTooltip(text: NSMutableAttributedString(attributedString: Localizable.vpnAcceleratorDescription.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: Localizable.vpnAcceleratorDescriptionAltLink, withUrl: VPNLink.vpnAccelerator.urlString)),
        ]
    }

    func displayState(for feature: (some ProvidableFeature & ToggleableFeature & Sendable).Type) -> PaidFeatureDisplayState {
        paidFeatureDisplayState(for: feature)
    }

    private var allowLanSection: [TableViewCellModel] {
        [
            .upsellableToggle(
                title: Localizable.allowLanTitle,
                state: { [unowned self] in displayState(for: ExcludeLocalNetworks.self) },
                upsell: { [weak self] in self?.upsellManager.present(.allowLan) },
                handler: switchLANCallback()
            ),
            .tooltip(text: Localizable.allowLanInfo),
        ]
    }

    private var hermesSection: [TableViewCellModel] {
        let hermesStatusLabel = hermesClient.isEnabled().wrappedValue ?
            Localizable.hermesSettingsIsOn :
            Localizable.hermesSettingsIsOff
        return [
            .upsellablePushKeyValue(
                title: Localizable.hermesFeatureTitle,
                state: { [unowned self] in displayState(for: HermesFeature.self) },
                value: hermesStatusLabel,
                icon: nil,
                upsell: { [weak self] in
                    self?.upsellManager.present(.hermes)
                },
                handler: { [weak self] in
                    self?.pushHermesViewController()
                }
            ),

            .attributedTooltip(
                text: NSMutableAttributedString(
                    attributedString: Localizable.hermesFeatureDescription
                        .attributed(
                            withColor: UIColor.weakTextColor(),
                            fontSize: 13
                        )
                ).add(
                    link: Localizable.learnMore,
                    withUrl: VPNLink.hermes.urlString
                )
            ),
        ]
    }

    private func pushHermesViewController() {
        DispatchQueue.main.async {
            let viewController = self.settingsService.makeHermesSettingsViewController(viewModel: self.hermesSettingsViewModel)
            viewController.onDidDisappear = { [weak self] in
                self?.showHermesReconnectionAlertIfNecessary()
            }
            self.push(viewController: viewController, hidesTranslucentNarBar: true, hidesBackBarButton: true)
        }
    }

    private var moderateNATState: PaidFeatureDisplayState {
        paidFeatureDisplayState(for: NATFeature.self, isEnabled: natTypePropertyProvider.getNATType() == .moderateNAT)
    }

    private var moderateNATSection: [TableViewCellModel] {
        [
            .upsellableToggle(
                title: Localizable.moderateNatTitle,
                overriddenValue: appliedNATOverride,
                isPending: applyingToggles.contains(.nat),
                state: { [unowned self] in moderateNATState },
                upsell: { [weak self] in self?.upsellManager.present(.moderateNat) },
                handler: { [weak self] toggleOn, callback in
                    let natType = toggleOn ? NATType.moderateNAT : NATType.strictNAT

                    self?.getFeatureChangeAvailability(for: .agent(.moderateNAT(natType))) { [weak self] featureChangeAvailability in
                        switch featureChangeAvailability {
                        case .withReconnect:
                            // We don't support any non cert-auth protocols on iOS.
                            log.assertionFailure("NATType should never require a reconnect on iOS")
                            fallthrough
                        case .withConnectionUpdate:
                            self?.natTypePropertyProvider.setNATType(natType)
                            self?.apply(agentFeatureChange: .moderateNAT(natType))
                            callback(toggleOn)
                            self?.markApplying(.nat)
                        case .immediate:
                            self?.natTypePropertyProvider.setNATType(natType)
                            callback(toggleOn)
                        }
                    }
                }
            ),
            .attributedTooltip(
                text: NSMutableAttributedString(
                    attributedString: Localizable.moderateNatExplanation
                        .attributed(
                            withColor: UIColor.weakTextColor(),
                            fontSize: 13
                        )
                ).add(
                    link: Localizable.moderateNatExplanationLink,
                    withUrl: VPNLink.moderateNAT.urlString
                )
            ),
        ]
    }

    private var alternativeRoutingSection: [TableViewCellModel] {
        @Shared(.alternativeRouting) var alternativeRouting
        return [
            .upsellableToggle(
                title: Localizable.troubleshootItemAltTitle,
                state: {
                    .available(enabled: alternativeRouting, interactive: true)
                },
                upsell: {}, // No Upsell: Alternative Routing is a free feature
                handler: { toggle, callback in
                    $alternativeRouting.withLock { $0 = toggle }
                    callback(toggle)
                }
            ),
            .attributedTooltip(text: NSMutableAttributedString(attributedString: Localizable.troubleshootItemAltDescription.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: Localizable.troubleshootItemAltLink1, withUrl: VPNLink.alternativeRouting.urlString)),
        ]
    }

    private var advancedSection: TableViewSection {
        var cells: [TableViewCellModel] = alternativeRoutingSection

        if featureFlags.moderateNAT {
            cells.append(contentsOf: moderateNATSection)
        }

        return TableViewSection(title: Localizable.advanced, cells: cells)
    }

    private var connectionSection: TableViewSection? {
        var cells: [TableViewCellModel] = []

        if featureFlags.vpnAccelerator {
            cells.append(contentsOf: vpnAcceleratorSection)
        }

        cells.append(contentsOf: allowLanSection)

        cells.append(contentsOf: hermesSection)

        return cells.isEmpty ? nil : TableViewSection(title: Localizable.connection, cells: cells)
    }

    private func switchLANCallback() -> ((Bool, @escaping (Bool) -> Void) -> Void) {
        { toggleOn, callback in
            let isActive = self.isActive()
            let excludeLAN = featureValue(for: ExcludeLocalNetworks.self)

            var alert: SystemAlert

            if self.killSwitch, excludeLAN == .off {
                alert = LANConnectionsKillSwitchConflictAlert(connected: isActive) {
                    setFeatureValue(ExcludeLocalNetworks.on)
                    self.$killSwitch.withLock { $0 = false }
                    if isActive {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks", "feature_additional": "killSwitch"])
                        self.reconnect(with: .allowLAN(false))
                    }
                    self.reloadNeeded?()
                    callback(true)
                } cancelHandler: {
                    callback(false)
                }
            } else if isActive {
                alert = ReconnectOnSettingsChangeAlert(confirmHandler: {
                    setFeatureValue(toggleOn ? ExcludeLocalNetworks.on : .off)
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks"])
                    self.reconnect(with: .allowLAN(false))
                    callback(toggleOn)
                }, cancelHandler: {
                    callback(featureValue(for: ExcludeLocalNetworks.self) == .on)
                })
            } else {
                setFeatureValue(toggleOn ? ExcludeLocalNetworks.on : .off)
                callback(toggleOn)
                return
            }

            self.alertService.push(alert: alert)
        }
    }

    private func ksSwitchCallback() -> ((Bool, @escaping (Bool) -> Void) -> Void) {
        { toggleOn, callback in
            let isActive = self.isActive()

            var alert: SystemAlert

            if featureValue(for: ExcludeLocalNetworks.self) == .on, !self.killSwitch {
                alert = KillSwitchConflictAlert {
                    setFeatureValue(ExcludeLocalNetworks.off)
                    self.$killSwitch.withLock { $0 = true }
                    if isActive {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch", "feature_additional": "excludeLocalNetworks"])
                        self.reconnect(with: .killSwitch(toggleOn))
                    }
                    self.reloadNeeded?()
                    callback(true)
                } cancelHandler: {
                    callback(false)
                }
            } else if isActive {
                alert = ReconnectOnSettingsChangeAlert(confirmHandler: {
                    self.$killSwitch.withLock { $0.toggle() }
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                    self.reconnect(with: .killSwitch(toggleOn))
                    callback(self.killSwitch)
                }, cancelHandler: {
                    callback(self.killSwitch)
                })
            } else {
                self.$killSwitch.withLock { $0.toggle() }
                callback(self.killSwitch)
                return
            }

            self.alertService.push(alert: alert)
        }
    }

    private var extensionsSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(
                title: Localizable.widget,
                handler: { [pushExtensionsViewController] in
                    pushExtensionsViewController()
                }
            ),
        ]

        return TableViewSection(title: Localizable.extensions, cells: cells)
    }

    private var usageStatisticsSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(
                title: Localizable.usageStatistics,
                handler: { [pushUsageStatisticsViewController] in
                    pushUsageStatisticsViewController()
                }
            ),
        ]

        return TableViewSection(title: "", cells: cells)
    }

    private var logSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(title: Localizable.viewLogs, handler: { [pushLogSelectionViewController] in
                pushLogSelectionViewController()
            }),
        ]

        return TableViewSection(title: "", cells: cells)
    }

    private var bottomSection: TableViewSection {
        @Dependency(\.credentiallessHelper) var credentiallessHelper
        let userIsCredentialLess = credentiallessHelper.isCredentialLess()
        var cells: [TableViewCellModel] = [
            .button(title: Localizable.reportBug, accessibilityIdentifier: Localizable.reportBug, color: .normalTextColor(), handler: { [reportBug] in
                reportBug()
            }),
        ]
        if !userIsCredentialLess {
            cells.append(
                .button(title: Localizable.logOut, accessibilityIdentifier: Localizable.logOut, color: .notificationErrorColor(), handler: { [logOut] in
                    logOut()
                })
            )
        }

        return TableViewSection(title: "", cells: cells)
    }

    private func pushSettingsAccountViewController() {
        guard let pushHandler, let accountViewController = settingsService.makeSettingsAccountViewController() else {
            return
        }
        pushHandler(accountViewController, false, false)
    }

    private func pushSignInToAnotherDeviceViewController() {
        Task { @MainActor in
            guard let pushHandler else {
                return
            }

            let passphrase: String = authKeychain.fetch()?.mailboxPassword ?? ""
            let email = authKeychain.username ?? Localizable.unavailable
            let apiService = networking.apiService

            let qrCodeInstructionsView = ScanQRCodeInstructionsView(
                viewModel: .init(
                    dependencies:
                    .init(
                        passphrase: passphrase,
                        userEmail: email,
                        apiService: apiService
                    )
                )
            )
            let hostingController = ShowingNavigationBarUIHostingController(
                rootView: AnyView(qrCodeInstructionsView)
            )

            hostingController.hidesBottomBarWhenPushed = true

            pushHandler(hostingController, false, false)
        }
    }

    private func pushAccountRecoveryViewController() {
        assert(isAccountRecoveryEnabled, "This function shall only be called when AccountRecovery flag is true.")
        guard let pushHandler else { return }
        let accountRecoveryViewController = settingsService.makeAccountRecoveryViewController()
        pushHandler(accountRecoveryViewController, false, false)
    }

    private func pushProtocolViewController() {
        @Shared(.smartProtocolConfig) var smartProtocolConfig
        let vpnProtocolViewModel = VpnProtocolViewModel(
            connectionProtocol: sharedConnectionProtocol,
            smartProtocolConfig: smartProtocolConfig,
            featureFlags: featureFlags
        )
        vpnProtocolViewModel.protocolChangeConfirmation = { [unowned self] newProtocol, completion in
            switch getProtocolChangeAvailability(for: newProtocol) {
            case .immediate:
                completion(.success(true))
                return

            case .protocolUnavailable:
                // If the server we're going to try to reconnect to with the new protocol doesn't support it, make
                // sure the user knows that the app is about to disconnect.
                alertService.push(alert: ProtocolNotAvailableForServerAlert(confirmHandler: {
                    log.debug(
                        "Disconnecting after changing protocols on a server which doesn't support \(newProtocol)",
                        category: .connectionDisconnect,
                        event: .trigger
                    )
                    completion(.success( /* shouldReconnect */ false))
                }, cancelHandler: {
                    completion(.failure(.userCancelled))
                }))

            case .withReconnect:
                // Otherwise, reconnect normally after changing the protocol.
                let alert = ChangeProtocolDisconnectAlert {
                    log.debug(
                        "Reconnect requested after changing protocol to \(newProtocol)",
                        category: .connectionDisconnect,
                        event: .trigger
                    )
                    completion(.success(true))
                }
                alert.dismiss = { completion(.failure(.userCancelled)) }
                alertService.push(alert: alert)
            }
        }

        vpnProtocolViewModel.protocolChanged = { [self] newProtocol, shouldReconnect in
            $sharedConnectionProtocol.withLock { $0 = newProtocol }

            switch getProtocolChangeAvailability(for: newProtocol) {
            case .immediate:
                break // we're not connected, so nothing needs to be done

            case .protocolUnavailable:
                requestDisconnect()

            case .withReconnect:
                if shouldReconnect {
                    reconnect(with: .connectionProtocol(newProtocol))
                } else {
                    requestDisconnect()
                }
            }
        }
        push(viewController: protocolService.makeVpnProtocolViewController(viewModel: vpnProtocolViewModel))
    }

    private func pushExtensionsViewController() {
        push(viewController: settingsService.makeExtensionsSettingsViewController())
    }

    private func pushUsageStatisticsViewController() {
        push(viewController: TelemetrySettingsViewController())
    }

    private func pushLogSelectionViewController() {
        push(viewController: settingsService.makeLogSelectionViewController())
    }

    private func pushNetshieldSelectionViewController() {
        let viewModel = NetShieldSelectionViewModel(
            title: Localizable.netshieldTitle,
            allFeatures: NetShieldType.allCases,
            selectedFeature: netShieldPropertyProvider.getNetShieldType(),
            factory: factory,
            onSelect: { [weak self] type, completion in self?.changeNetShieldType(to: type, completion: completion) }
        )
        push(viewController: NetShieldSelectionViewController(viewModel: viewModel))
    }

    private func changeNetShieldType(to type: NetShieldType, completion: @escaping (Bool) -> Void) {
        let result = netShieldTypeAuthorizer(type)
        guard result.isAllowed else {
            if result.requiresUpgrade {
                upsellManager.present(.netShield)
            }
            completion(false)
            return
        }
        getFeatureChangeAvailability(for: .agent(.netShield(type))) { [weak self] featureChangeAvailability in
            switch featureChangeAvailability {
            case .withReconnect:
                // We don't support any non cert-auth protocols on iOS.
                log.assertionFailure("NetShield should never require a reconnect on iOS")
                fallthrough
            case .withConnectionUpdate:
                let setNetShieldValue: (NetShieldType) -> Void = { [weak self] newValue in
                    self?.netShieldPropertyProvider.setNetShieldType(newValue)
                    self?.apply(agentFeatureChange: .netShield(newValue))
                }
                if case .off = type {
                    setNetShieldValue(type)
                    completion(true)
                } else {
                    self?.showHermesNetshieldOnConflictAlertIfNecessary { enable in
                        if enable {
                            self?.hermesSettingsViewModel.setIsEnabled(false, force: true)
                            setNetShieldValue(type)
                        }
                        completion(enable)
                    }
                }
            case .immediate:
                if case .off = type {
                    self?.netShieldPropertyProvider.setNetShieldType(type)
                    completion(true)
                } else {
                    self?.showHermesNetshieldOnConflictAlertIfNecessary { enable in
                        if enable {
                            self?.hermesSettingsViewModel.setIsEnabled(false, force: true)
                            self?.netShieldPropertyProvider.setNetShieldType(type)
                        }
                        completion(enable)
                    }
                }
            }
        }
    }

    private func showHermesNetshieldOnConflictAlertIfNecessary(completionHandler: @escaping (_ shouldEnableNetShield: Bool) -> Void) {
        guard hermesSettingsViewModel.isEnabled else {
            completionHandler(true)
            return
        }

        let alertController = hermesSettingsViewModel.netShieldOnConflictAlertController {
            completionHandler($0)
        }

        showModalController?(alertController)
    }

    private func showHermesReconnectionAlertIfNecessary() {
        hermesSettingsViewModel.isReconnectionNecessaryFromHermesChange { [weak self] reconnectionIsNecessary in
            guard reconnectionIsNecessary else {
                return
            }
            self?.showReconnectionAlertController(hermesWillBeEnabled: true)
        }
    }

    private func showNetShieldReconnectionAlertIfNecessary(cancelHandler: (() -> Void)? = nil) {
        hermesSettingsViewModel.isReconnectionNecessaryFromNetShieldChange { [weak self] reconnectionIsNecessary in
            guard reconnectionIsNecessary else {
                return
            }
            self?.showReconnectionAlertController(hermesWillBeEnabled: false, cancelHandler: cancelHandler)
        }
    }

    private func showReconnectionAlertController(hermesWillBeEnabled: Bool, cancelHandler: (() -> Void)? = nil) {
        let alertController = hermesSettingsViewModel.reconnectionAlertController { [weak self] shouldReconnect in
            if shouldReconnect {
                self?.reconnect(with: .customDNS(hermesWillBeEnabled), showStatusViewController: true)
            } else {
                cancelHandler?()
            }
        }
        showModalController?(alertController)
    }

    private var userTier: Int {
        do {
            return try vpnKeychain.fetchCached().maxTier
        } catch {
            log.warning("Failed to retrieve user tier, defaulting to free tier.", category: .keychain)
            return .freeTier
        }
    }

    private func reportBug() {
        settingsService.presentReportBug()
    }

    private func logOut() {
        if isActive() {
            let confirmationClosure: () -> Void = { [weak self] in
                self?.appSessionManager.logOut(force: true, reason: nil)
            }
            alertService.push(alert: LogoutWarningAlert(confirmHandler: confirmationClosure))
        } else {
            appSessionManager.logOut(force: false, reason: nil)
        }
    }

    func isActive() -> Bool {
        settingsClient.isActive()
    }

    private func getProtocolChangeAvailability(
        for connectionProtocol: ConnectionProtocol
    ) -> ProtocolChangeAvailability {
        settingsClient.protocolChangeAvailability(connectionProtocol)
    }

    private func getFeatureChangeAvailability(
        for featureChange: ConnectionFeatureChange,
        completion: @escaping (VpnFeatureChangeState) -> Void
    ) {
        completion(settingsClient.featureChangeAvailability(featureChange))
    }

    private func requestDisconnect(completionHandler: (@MainActor () -> Void)? = nil) {
        Task {
            do {
                try await settingsClient.disconnect()
                await completionHandler?()
            } catch {
                log.error("Failed to disconnect: \(error)", category: .connection)
                await completionHandler?()
            }
        }
    }

    private func apply(agentFeatureChange: ConnectionFeatureChange.AgentFeature) {
        DispatchQueue.main.async {
            self.settingsClient.update(Set([agentFeatureChange]))
        }
    }

    private func reconnect(with tunnelFeatureChange: ConnectionFeatureChange.TunnelFeature, showStatusViewController: Bool = false) {
        // KS and LAN features are applied by the viewmodel.
        // We only need to worry about updating the protocol here.
        if case let .connectionProtocol(connectionProtocol) = tunnelFeatureChange {
            @Shared(.connectionProtocol) var sharedConnectionProtocol
            $sharedConnectionProtocol.withLock { $0 = connectionProtocol }
        }
        if showStatusViewController {
            connectionStatusService.presentStatusViewController()
        }
        Task {
            do {
                try await settingsClient.reconnect(Set([tunnelFeatureChange]))
            } catch {
                log.error("Failed to reconnect: \(error)", category: .connection)
            }
        }
    }

    private func retryConnection() {
        @Shared(.connectionProtocol) var connectionProtocol
        connectionCommandClient.send(.reconnect(connectionProtocol))
    }

    private func presentSignUpScreen() {
        navigationService.presentSignUp()
    }

    private func presentSignInScreen() {
        navigationService.presentLogin()
    }
}

class ShowingNavigationBarUIHostingController: UIHostingController<AnyView> {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

private extension SettingsViewModel {
    static var shouldShowProTUN: Bool {
        // This should work once we rename the Staging configuration to Debug-Staging
        #if DEBUG
            return true
        #else
            return Bundle.main.isStagingBuild
        #endif
    }
}

private extension Bundle {
    var isStagingBuild: Bool {
        bundleIdentifier?.contains("debug") ?? false
    }
}
