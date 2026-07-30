//
//  ConnectionSettingsViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa
import Combine
import CommonNetworking
import Connection
import Dependencies
import Domain
import LegacyCommon
import Persistence
import Settings
import Sharing
import Strings
import Theme
import VPNAppCore
import VPNShared

enum ConnectionSettingsError: FourCharCode, ProtonVPNError {
    static let errorDomain: String = "ConnectionSettingsErrorDomain"

    case autoConnectRange = "CSAR"
    case quickConnectRange = "CSQR"
}

final class ConnectionSettingsViewModel {
    @Dependency(\.profileAuthorizer) var profileAuthorizer
    @Dependency(\.featureAuthorizerProvider) var authorizerProvider

    typealias Factory = NavigationServiceFactory & VpnProtocolChangeManagerFactory

    private let factory: Factory
    private typealias ProtocolSwitchAction = VpnProtocolChangeManagerImplementation.ProtocolSwitchAction

    @Dependency(\.profileManager) private var profileManager
    @Dependency(\.systemExtensionsCoordinator) private var systemExtensionsCoordinator
    @Dependency(\.coreAlertService) private var alertService
    @Dependency(\.upsellManager) private var upsellManager
    @Dependency(\.serverRepository) private var serverRepository
    @Dependency(\.credentialsProvider) private var credentialsProvider
    private lazy var vpnProtocolChangeManager: VpnProtocolChangeManager = factory.makeVpnProtocolChangeManager()
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    private lazy var navService: NavigationService = factory.makeNavigationService()
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    var selectedProtocol: ConnectionProtocol {
        didSet {
            if selectedProtocol != oldValue {
                reloadNeeded?()
            }
        }
    }

    var sysexPending: Bool {
        didSet {
            protocolPendingChanged?(sysexPending)
        }
    }

    @SharedReader(.featureFlags) private var featureFlags: FeatureFlags
    @SharedReader(.connectionProtocol) private var sharedConnectionProtocol: ConnectionProtocol
    @Shared(.smartProtocol) private var sharedSmartProtocol: Bool

    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    private let vpnAcceleratorReader = AuthorizedFeatureValue<VPNAccelerator>().sharedReader()
    private let excludeLocalNetworksReader = AuthorizedFeatureValue<ExcludeLocalNetworks>().sharedReader()
    private var observations = Set<AnyCancellable>()
    private var portForwardingObservationTask: Task<Void, Never>?

    var reloadNeeded: (() -> Void)?
    var protocolPendingChanged: ((Bool) -> Void)?

    init(factory: Factory) {
        self.factory = factory
        self.sysexPending = true
        self.selectedProtocol = .smartProtocol // dummy value must be assigned before we can access stored settings
        self.selectedProtocol = sharedConnectionProtocol

        AppEvent.profileContentChanged.subscribe(self, selector: #selector(settingsChanged))

        // Refresh the screen when settings backed by `@Shared` / property providers change. These no
        // longer post `AppEvent`s, so observe their publishers/streams directly.
        $sharedConnectionProtocol.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &observations)

        vpnAcceleratorReader.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &observations)

        excludeLocalNetworksReader.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &observations)

        self.portForwardingObservationTask = Task { [weak self] in
            for await _ in portForwardingPropertyProvider.portForwardingStream().dropFirst() {
                await MainActor.run { self?.settingsChanged() }
            }
        }

        AppEvent.systemExtensionTourCancelled.subscribe(self, selector: #selector(tourCancelled))

        checkSysexOrResetProtocol(selectedProtocol)
    }

    deinit {
        portForwardingObservationTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Available protocols and Profiles

    lazy var availableConnectionProtocols: [ConnectionProtocol] = ConnectionProtocol.availableProtocols(wireguardTLSEnabled: featureFlags.wireGuardTls)
        .appending(selectedProtocol) // Edge case - user's protocol has been deprecated. Show it as disabled
        .uniqued
        .sorted(by: ConnectionProtocol.uiSort)

    var availableProfiles: [Profile] {
        guard profileAuthorizer.canUseProfiles else {
            // On the free plan, post-rescope, we should only show the 'fastest' auto-connect option
            return [ProfileConstants.fastestProfile(
                connectionProtocol: sharedConnectionProtocol,
                defaultProfileAccessTier: .free
            )]
        }
        return profileManager.allProfiles()
    }

    // MARK: - Quick and auto connect for current user

    @Shared(.autoConnect) private var sharedAutoConnect
    @Shared(.autoConnectProfileId) private var sharedAutoConnectProfileId

    var autoConnect: (enabled: Bool, profileId: String?)? {
        get {
            (sharedAutoConnect, sharedAutoConnectProfileId)
        }
        set {
            guard let newValue else { return }
            $sharedAutoConnect.withLock { $0 = newValue.enabled }
            if let profileId = newValue.profileId {
                $sharedAutoConnectProfileId.withLock { $0 = profileId }
            }
        }
    }

    @Shared(.quickConnect) private var sharedQuickConnect

    var quickConnect: String? {
        get {
            sharedQuickConnect
        }
        set {
            $sharedQuickConnect.withLock { $0 = newValue }
        }
    }

    // MARK: - Current Index

    var autoConnectProfileIndex: Int {
        guard let autoConnect, autoConnect.enabled else { return 0 }

        guard let profileId = autoConnect.profileId else { return 1 }
        let index = availableProfiles.firstIndex {
            $0.id == profileId
        }

        guard let profileIndex = index else { return 1 }
        let listIndex = profileIndex + 1
        guard listIndex < autoConnectItemCount else { return 1 }
        return listIndex
    }

    var quickConnectProfileIndex: Int {
        guard let profileId = quickConnect else { return 0 }
        let index = profileManager.allProfiles().firstIndex {
            $0.id == profileId
        }

        guard let profileIndex = index, profileIndex < quickConnectItemCount else { return 0 }
        return profileIndex
    }

    func displayState(for feature: (some ProvidableFeature & ToggleableFeature & Sendable).Type) -> PaidFeatureDisplayState {
        paidFeatureDisplayState(for: feature)
    }

    // MARK: - Item counts

    var autoConnectItemCount: Int {
        availableProfiles.count + 1 // Add one to account for the 'disabled' option
    }

    var quickConnectItemCount: Int {
        availableProfiles.count
    }

    var protocolItemCount: Int {
        availableConnectionProtocols.count
    }

    // MARK: - Setters

    func setAutoConnect(_ index: Int) throws {
        guard index < autoConnectItemCount else {
            throw ConnectionSettingsError.autoConnectRange
        }

        if index > 0 {
            let selectedProfile = availableProfiles[index - 1]
            autoConnect = (enabled: true, profileId: selectedProfile.id)
            log.debug("Autoconnect profile changed", category: .settings, event: .change, metadata: ["profile": "\(selectedProfile.logDescription)"])
        } else {
            autoConnect = (enabled: false, profileId: nil)
            log.debug("Autoconnect profile changed", category: .settings, event: .change, metadata: ["profile": "nil"])
        }
    }

    func setQuickConnect(_ index: Int) throws {
        guard index < quickConnectItemCount else {
            throw ConnectionSettingsError.quickConnectRange
        }

        let selectedProfile = profileManager.allProfiles()[index]
        quickConnect = selectedProfile.id
        log.debug("Quick connect profiles changed", category: .settings, event: .change, metadata: ["profile": "\(selectedProfile.logDescription)"])
    }

    func protocolIndex(for vpnProtocol: ConnectionProtocol) -> Int {
        guard let result = availableConnectionProtocols.firstIndex(of: vpnProtocol) else {
            log.assertionFailure("Protocol \(vpnProtocol) was not in available protocols list")
            return 0
        }

        return result
    }

    func protocolItem(for index: Int) -> ConnectionProtocol? {
        guard index < availableConnectionProtocols.count else {
            return nil
        }

        return availableConnectionProtocols[index]
    }

    func refreshSysexPending(for connectionProtocol: ConnectionProtocol) {
        sysexPending = connectionProtocol.requiresSystemExtension
    }

    func shouldShowSysexProgress(for protocolIndex: Int) -> Bool {
        protocolItem(for: protocolIndex)?.requiresSystemExtension == true && sysexPending
    }

    func setProtocol(_ connectionProtocol: ConnectionProtocol, completion: @escaping (Result<Void, Error>) -> Void) {
        guard connectionProtocol != selectedProtocol else { return }
        sysexPending = true
        switch connectionProtocol {
        case .smartProtocol:
            confirmEnableSmartProtocol(completion)
        case let .vpnProtocol(transportProtocol):
            let changeCompletionHandler: (Result<Void, Error>) -> Void = { [weak self] result in
                self?.sysexPending = false
                if case .success = result {
                    self?.$sharedSmartProtocol.withLock { $0 = false }
                    self?.selectedProtocol = connectionProtocol
                }
                completion(result)
            }

            guard transportProtocol == .ike else {
                vpnProtocolChangeManager.change(
                    toProtocol: transportProtocol,
                    userInitiated: true,
                    completion: changeCompletionHandler
                )
                return
            }

            // Show IKEv2 deprecation warning
            alertService.push(alert: IkeDeprecatedAlert(enableSmartProtocolHandler: { [weak self] in
                guard let self else {
                    return
                }
                SentryHelper.shared?.log(message: "IKEv2 Deprecation: User accepted to switch to Smart protocol.")
                confirmEnableSmartProtocol(completion)
            }, continueHandler: { [weak self] in
                guard let self else {
                    return
                }
                SentryHelper.shared?.log(message: "IKEv2 Deprecation: User decided to continue with IKEv2 anyway.")
                vpnProtocolChangeManager.change(
                    toProtocol: transportProtocol,
                    userInitiated: true,
                    completion: changeCompletionHandler
                )
                @Shared(.plutoniumFeature) var plutonium
                $plutonium.withLock { $0.disable() }
                // Advanced kill switch cannot apply over IKEv2. Fall back to Standard, as announced in the alert body.
                @Shared(.killSwitchMode) var killSwitchMode
                if killSwitchMode.isAdvanced {
                    $killSwitchMode.withLock { $0 = .standard }
                }
            }, learnMoreHandler: {
                SentryHelper.shared?.log(message: "IKEv2 Deprecation: User opened Learn more; keeping the current (Smart) protocol selection.")
                // Don't select IKEv2: revert the picker to its previous selection
                changeCompletionHandler(.failure(CancellationError()))
            }))
        }
    }

    @objc
    private func settingsChanged() {
        reloadNeeded?()
    }

    @objc
    private func tourCancelled() {
        reloadNeeded?()
    }

    func confirmEnableSmartProtocol(_ completion: @escaping (Result<Void, Error>) -> Void) {
        switch connectionState {
        case .connected, .connecting:
            @SharedReader(.smartProtocolConfig) var smartProtocolConfig
            let config = smartProtocolConfig
            let supported = connectionState.resolvedServer?.endpoint.supports(protocolSet: ProtocolSupport(vpnProtocols: config.supportedProtocols)) ?? false

            let alert: SystemAlert = if supported {
                ReconnectOnSmartProtocolChangeAlert(confirmHandler: { [weak self] in
                    self?.enableSmartProtocol(and: .reconnect, completion)
                }, cancelHandler: {
                    completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
                })
            } else {
                ProtocolNotAvailableForServerAlert(confirmHandler: { [weak self] in
                    log.info(
                        "User changed to smart protocol, even though current server doesn't support it",
                        category: .connectionConnect,
                        event: .trigger,
                        metadata: ["smartProtocolConfig": "\(config)"]
                    )
                    self?.enableSmartProtocol(and: .disconnect, completion)
                }, cancelHandler: {
                    log.info(
                        "User did not change to smart protocol, since current server doesn't support it",
                        category: .connectionConnect,
                        event: .trigger,
                        metadata: ["smartProtocolConfig": "\(config)"]
                    )
                    completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
                })
            }
            alertService.push(alert: alert)

        case .resolving, .disconnected, .disconnecting, .killSwitchActive:
            enableSmartProtocol(and: .doNothing, completion)
        }
    }

    private func enableSmartProtocol(and then: ProtocolSwitchAction, _ completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await systemExtensionsCoordinator.installOrUpdate(
                origin: .connectionSettings,
                shouldStartTour: true,
                includedTypes: [.proTUN]
            )
            let result = outcome.accumulated
            sysexPending = false

            switch result {
            case .success:
                $sharedSmartProtocol.withLock { $0 = true }
                selectedProtocol = .smartProtocol

                switch then {
                case .disconnect:
                    log.info(
                        "Will disconnect after VPN feature change",
                        category: .connectionConnect,
                        event: .trigger,
                        metadata: ["feature": "smartProtocol"]
                    )
                    connectionCommandClient.send(.disconnect(.auto, completion: {
                        completion(.success)
                    }))
                case .reconnect:
                    log.info(
                        "Connection will restart after VPN feature change",
                        category: .connectionConnect,
                        event: .trigger,
                        metadata: ["feature": "smartProtocol"]
                    )
                    connectionCommandClient.send(.reconnect(.smartProtocol))
                    completion(.success)
                case .doNothing:
                    log.info(
                        "Smart protocol was enabled",
                        category: .connectionConnect,
                        event: .trigger,
                        metadata: ["feature": "smartProtocol"]
                    )
                    completion(.success)
                }
            case let .failure(error):
                if case let .installationError(installError) = error,
                   let alert = SysexInstallingErrorAlert(error: installError) {
                    alertService.push(alert: alert)
                }
                completion(.failure(error))
            }

            try? await Task.sleep(for: .milliseconds(150))
            reloadNeeded?()
        }
    }

    private func checkSysexOrResetProtocol(_: ConnectionProtocol) {
        sysexPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await systemExtensionsCoordinator.checkAndInstallOrUpdate(
                origin: .connectionSettings,
                shouldStartTour: false,
                includedTypes: [.proTUN]
            )
            let result = outcome.accumulated
            sysexPending = false
            if case .failure = result {
                selectedProtocol = .vpnProtocol(.ike)
            }
        }
    }

    func setVpnAccelerator(_ enabled: Bool, completion: @escaping ((Bool) -> Void)) {
        let newValue: VPNAccelerator = enabled ? .on : .off
        switch VpnFeatureChangeState(connectionState: connectionState) {
        case .withConnectionUpdate:
            // in-place change when connected and using local agent
            setFeatureValue(newValue)
            connectionCommandClient.send(.applySettings([.agent(.vpnAccelerator(enabled))]))
            completion(true)
        case .withReconnect:
            alertService.push(alert: ReconnectOnActionAlert(actionTitle: Localizable.vpnProtocol, confirmHandler: { [weak self] in
                setFeatureValue(newValue)
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "vpnAccelerator"])
                self?.connectionCommandClient.send(.retry)
                completion(true)
            }, cancelHandler: {
                completion(false)
            }))
        case .immediate:
            setFeatureValue(newValue)
            completion(true)
        }
    }

    func setPortForwardingNotifications(_ enabled: Bool, completion: @escaping ((Bool) -> Void)) {
        let newValue: PortForwardingNotifications = enabled ? .on : .off
        setFeatureValue(newValue)
        completion(true)
    }

    func setAllowLANAccess(_ enabled: Bool, completion: @escaping ((Bool) -> Void)) {
        let newValue: ExcludeLocalNetworks = enabled ? .on : .off

        // Also allow live updates for LAN access when the zero-peer kill switch is active.
        let changeState: VpnFeatureChangeState = connectionState.is(\.killSwitchActive)
            ? .withConnectionUpdate
            : .init(connectionState: connectionState)

        switch changeState {
        case .withConnectionUpdate:
            setFeatureValue(newValue)
            connectionCommandClient.send(.applySettings([.tunnel(.allowLAN(enabled))]))
            completion(true)
        case .withReconnect:
            // IKEv2 reads `excludeLocalNetworks` when the connection is established and has no channel for in-place
            // updates, so a live change needs the user to agree to a reconnect.
            alertService.push(alert: ReconnectOnSettingsChangeAlert(confirmHandler: {
                setFeatureValue(newValue)
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks"])
                self.connectionCommandClient.send(.retry)
                completion(true)
            }, cancelHandler: {
                completion(false)
            }))
        case .immediate:
            setFeatureValue(newValue)
            completion(true)
        }
    }

    // MARK: - Upsell Modals

    func showLANConnectionUpsell() {
        upsellManager.present(.allowLan)
    }

    func showVPNAcceleratorUpsell() {
        upsellManager.present(.vpnAccelerator)
    }

    func showPlutoniumUpsell() {
        upsellManager.present(.splitTunneling)
    }

    func showPortForwardingUpsell() {
        upsellManager.present(.portForwarding)
    }

    // MARK: - Item

    func autoConnectItem(for index: Int) -> NSAttributedString {
        if index > 0 {
            return profileString(for: index - 1)
        } else {
            let imageAttributedString = attributedAttachment(style: .weak)
            return concatenated(imageString: imageAttributedString, with: Localizable.disabled, enabled: true)
        }
    }

    // Don't show quick connect customisation if user is not authorized to use profiles
    var shouldShowQuickConnect: Bool {
        profileAuthorizer.canUseProfiles
    }

    var shouldShowPFNotifications: Bool {
        // Port-forwarding notifications are a paid feature
        credentialsProvider.tier.isPaid
    }

    func quickConnectItem(for index: Int) -> NSAttributedString {
        profileString(for: index)
    }

    func protocolString(for vpnProtocol: ConnectionProtocol) -> NSAttributedString {
        vpnProtocol.description.styled(.dropdown, font: .themeFont(.heading4), alignment: .left)
    }

    // MARK: - Values

    private func attributedAttachment(style: AppTheme.Style, width: CGFloat = 12) -> NSAttributedString {
        let profileCircle = ProfileCircle(frame: CGRect(x: 0, y: 0, width: width, height: width))
        profileCircle.profileColor = .color(.icon, style)
        let data = profileCircle.dataWithPDF(inside: profileCircle.bounds)
        let image = NSImage(data: data)
        let attachmentCell = NSTextAttachmentCell(imageCell: image)
        let attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        return NSAttributedString(attachment: attachment)
    }

    private func concatenated(imageString: NSAttributedString, with text: String, enabled: Bool) -> NSAttributedString {
        let style: AppTheme.Style = enabled ? .dropdown : [.transparent, .disabled]
        let nameAttributedString = ("  " + text).styled(style, font: .themeFont(.heading4))
        let attributedString = NSMutableAttributedString(attributedString: NSAttributedString.concatenate(imageString, nameAttributedString))
        let range = (attributedString.string as NSString).range(of: attributedString.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        attributedString.setAlignment(.left, range: range)
        return attributedString
    }

    private func profileString(for index: Int) -> NSAttributedString {
        guard availableProfiles.indices.contains(index) else {
            log.error("Profile index (\(index)) out of bounds of available profiles array (\(availableProfiles.count).")
            return .init()
        }
        let profile = availableProfiles[index]
        let lowestServerTier = serverRepository.serverAvailability(for: profile).lowestServerTier
        // Free users only see the default 'fastest' profile here, because `availableProfiles` already
        // hides the rest from them. So here we just check the user's tier is high enough for this
        // server. We don't use `canUseProfile` because it also requires a paid plan, which would
        // wrongly grey out the free user's only option.
        let enabled = credentialsProvider.tier >= lowestServerTier
        return concatenated(imageString: profile.profileIcon.attributedAttachment(), with: profile.name, enabled: enabled)
    }

    func showPlutoniumSettings() {
        navService.showPlutonium()
    }
}
