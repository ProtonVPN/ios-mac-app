//
//  Created on 18/11/2025 by Max Kupetskyi.
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

import Foundation
import UIKit

import Dependencies

import Connection
import Domain
import Ergonomics
import ExtensionIPC
import LegacyCommon
import PMLogger
import Settings
import VPNAppCore
import VPNShared

import ProtonCoreAccountRecovery
import ProtonCoreEnvironment
import ProtonCoreFeatureFlags
import ProtonCoreForceUpgrade
import ProtonCoreLog
import ProtonCoreNetworking
import ProtonCoreObservability
import ProtonCorePushNotifications
import ProtonCoreServices
import ProtonCoreTelemetry
import ProtonCoreUIFoundations

import Announcement
import Logging
import Sharing

/// Implementation of AppDelegateProtocol that encapsulates all app delegate logic within the ios_app package.
public final class AppDelegateService: AppDelegateProtocol {
    private static let acceptedDeepLinkChallengeInterval: TimeInterval = 10
    private static let sessionAcquisitionTimeout: Duration = .seconds(5)

    @Dependency(\.networking) private var networking
    @Dependency(\.defaultsProvider) private var defaultsProvider
    @Dependency(\.cryptoService) private var cryptoService
    @Dependency(\.authKeychain) private var authKeychain
    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.propertiesManager) private var propertiesManager

    private let container: DependencyContainer
    private lazy var vpnManager: VpnManagerProtocol = container.makeVpnManager()
    private lazy var appSessionManager: AppSessionManager = container.makeAppSessionManager()
    private lazy var navigationService: NavigationService = container.makeNavigationService()
    private lazy var appStateManager: AppStateManager = container.makeAppStateManager()
    private lazy var planService: PlanService = container.makePlanService()
    private lazy var telemetrySettings: TelemetrySettings = container.makeTelemetrySettings()
    private lazy var pushNotificationService = container.makePushNotificationService()

    private var tokens: [NotificationToken] = []

    public init() {
        self.container = DependencyContainer.shared
    }

    // MARK: - AppDelegateProtocol

    public func performEarlySetup() {
        setupLogsForApp()

        // WARNING: Be sure `setUpNSCoding` is run before there is a slight chance that we'll be decoding ANYTHING.
        // Force all encoded objects to be decoded and recoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")

        // Clear out any overrides that may have been present in previous builds
        FeatureFlagsRepository.shared.resetOverrides()

        FeatureFlagsRepository.shared.setFlagOverride(CoreFeatureFlagType.dynamicPlan, true)

        // Next, properly set the feature flag overrides in the repository.
        for (name, value) in propertiesManager.featureFlagOverrides ?? [:] {
            guard let feature = ManuallySpecifiedFeatureFlag(rawValue: name) else { continue }
            FeatureFlagsRepository.shared.setFlagOverride(feature, value)
        }
    }

    public func applicationDidFinishLaunching() {
        @Dependency(\.buildConfigurationChecker) var buildConfigurationChecker
        if buildConfigurationChecker.buildConfiguration() == .debug {
            #if targetEnvironment(simulator)
                // Force log out if running UI tests
                if ProcessInfo.processInfo.arguments.contains("UITests") {
                    appSessionManager.logOut(force: false, reason: "UI tests")
                }
            #endif
        }
        log.info("applicationDidFinishLaunchingWithOptions", category: .os)

        AnnouncementButtonViewModel.shared = container.makeAnnouncementButtonViewModel()
        Task { @MainActor in
            setupDebugHelpers()

            await setupCoreIntegration()

            // Make sure AppStateManager is ready and is created on the main thread
            _ = appStateManager

            // Note: Siri intent setup is handled in the main app target since it depends on Intent definitions
            LegacyDefaultsMigration.migrateLargeData(from: defaultsProvider.getDefaults())

            // Protocol check is placed here for parity with MacOS
            adjustGlobalProtocolIfNecessary()

            // Sentry turned off, because https://github.com/getsentry/sentry-cocoa/issues/1892
            // is still not fixed.
            // ```
            //  if VPNFeatureFlagType.sentry.enabled {
            //      SentryHelper.setupSentry(
            //          dsn: ObfuscatedConstants.sentryDsniOS,
            //          isEnabled: { [weak self] in
            //              self?.isTelemetryAllowed() ?? false
            //          },
            //          getUserId: { [weak self] in
            //              self?.authKeychain.userId
            //          }
            //      )
            //  }
            // ```

            await vpnManager.prepareManagersTask?.value
            await self.navigationService.launched()
        }

        container.makeMaintenanceManagerHelper().startMaintenanceManager()

        _ = container.makeDynamicBugReportManager() // Loads initial bug report config and sets up a timer to refresh it daily.

        container.applicationDidFinishLaunching()

        registerForTelemetryChanges()

        startObservingNetworkingEvents()
    }

    public func applicationWillEnterForeground() {
        appStateManager.refreshState()
    }

    public func applicationDidEnterBackground() {
        log.info("applicationDidEnterBackground", category: .os)
        vpnManager.appBackgroundStateDidChange(isBackground: true)
    }

    public func applicationDidBecomeActive() {
        log.info("applicationDidBecomeActive", category: .os)
        vpnManager.appBackgroundStateDidChange(isBackground: false)

        switchToHomeIfConnectingAndRedesign()

        // Refresh API announcements
        @Dependency(\.announcementRefresher) var announcementRefresher: AnnouncementRefresher
        if propertiesManager.featureFlags.pollNotificationAPI, authKeychain.username != nil {
            announcementRefresher.tryRefreshing()
        }
        Task { @MainActor in
            try? await container.makeAppSessionManager().refreshVpnAuthCertificate()
            container.makeReview().activated()
        }
    }

    public func handleOpenURL(_ url: URL, options _: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            log.error("Invalid URL", category: .app)
            return false
        }

        let verified = isVerifiedUrl(components)
        return handleAction(host, verified: verified)
    }

    public func handleContinueUserActivity(_ userActivity: NSUserActivity) -> Bool {
        // Handle Siri intents
        let prefix = "com.protonmail.vpn."
        guard userActivity.activityType.hasPrefix(prefix) else {
            return false
        }

        let action = String(userActivity.activityType.dropFirst(prefix.count))

        // We know the action is verified because the user activity has our prefix.
        let verified = true
        return handleAction(action, verified: verified)
    }

    public func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        pushNotificationService.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    public func didFailToRegisterForRemoteNotifications(withError error: Error) {
        pushNotificationService.didFailToRegisterForRemoteNotifications(withError: error)
    }

    // MARK: - Private Methods

    private func setupLogsForApp() {
        @Dependency(\.logFileManager) var logFileManager
        let logFile = logFileManager.getFileUrl(named: AppConstants.Filenames.appLogFilename)

        let fileLogHandler = FileLogHandler(logFile)
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        let multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        LoggingSystem.bootstrap { _ in multiplexLogHandler }
    }

    private func setupDebugHelpers() {
        @Dependency(\.buildConfigurationChecker) var buildConfigurationChecker
        if buildConfigurationChecker.buildConfiguration() == .debug {
            CertificateConstants.certificateDuration = "10 minutes"
        }
    }

    private func handleAction(_ action: String, verified: Bool = false) -> Bool {
        switch action {
        case URLConstants.deepLinkLoginAction:
            DispatchQueue.main.async { [weak self] in
                self?.navigationService.presentWelcome(initialError: nil)
            }

        case URLConstants.deepLinkConnectAction:
            // Action may only come from a trusted source
            guard verified else { return false }

            // Extensions requesting a connection should set a connection request first
            navigationService.vpnGateway.quickConnect(trigger: .widget)
            AppEvent.connectionStateChanged.subscribe(self, selector: #selector(stateDidUpdate))
            navigationService.presentStatusViewController()

        case URLConstants.deepLinkDisconnectAction:
            // Action may only come from a trusted source
            guard verified else { return false }

            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.disconnect(.widget))
            navigationService.vpnGateway.disconnect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }

        case URLConstants.deepLinkRefresh, URLConstants.deepLinkRefreshAccount:
            guard authKeychain.username != nil else {
                log.debug("User is not logged in, not refreshing user data", category: .app)
                return false
            }

            log.debug("App activated with the refresh url, refreshing data", category: .app)
            Task { @MainActor in
                do {
                    try await container.makeAppSessionManager().attemptSilentLogIn()
                    log.debug("User data refreshed after url activation", category: .app)
                } catch {
                    log.error("User data failed to refresh after url activation", category: .app, metadata: ["error": "\(error)"])
                }

                AppEvent.urlActivationRefresh.post()
            }

        default:
            log.error("Invalid url action", category: .app, metadata: ["action": "\(action)"])
            return false
        }

        return true
    }

    @objc
    private func stateDidUpdate() {
        switch appStateManager.state {
        case .connected:
            NotificationCenter.default.removeObserver(self)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
            }
        case .connecting, .preparingConnection:
            // wait
            return
        default:
            NotificationCenter.default.removeObserver(self)
            return
        }
    }

    private func isVerifiedUrl(_ components: URLComponents) -> Bool {
        guard let queryItems = components.queryItems,
              let t = queryItems.first(where: { $0.name == "t" })?.value,
              var timestamp = Int(t) else {
            return false
        }

        let timestampDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let interval = Date().timeIntervalSince(timestampDate)
        guard interval < Self.acceptedDeepLinkChallengeInterval else {
            return false
        }

        let algorithm = CryptoConstants.widgetChallengeAlgorithm
        guard let s = queryItems.first(where: { $0.name == "s" })?.value?.data(using: .utf8),
              let a = queryItems.first(where: { $0.name == "a" })?.value,
              a == algorithm.stringValue,
              let signature = Data(base64Encoded: s) else {
            return false
        }

        let challenge = withUnsafeBytes(of: &timestamp) { Data($0) }

        do {
            let publicKey = try vpnKeychain.fetchWidgetPublicKey()
            if try cryptoService.verify(signature: signature, of: challenge, with: publicKey, using: algorithm) {
                return true
            }
        } catch {
            log.error("Couldn't verify url: \(error)")
        }

        log.error("Verification of url failed: \(components)")
        return false
    }

    private func adjustGlobalProtocolIfNecessary() {
        if propertiesManager.connectionProtocol.isDeprecated {
            propertiesManager.connectionProtocol = .smartProtocol
        }
    }

    private func switchToHomeIfConnectingAndRedesign() {
        @SharedReader(.connectionState) var connectionState: ConnectionState
        switch connectionState {
        case .connecting, .resolving:
            log.debug("Connection state is resolving or connecting, navigating to Home", category: .app)
            container.makeNavigationService().presentStatusViewController()
        default:
            break
        }
    }

    // MARK: - Core Integration

    private func setupCoreIntegration() async {
        // Note: injectDefaultCryptoImplementation() is called in the main app target
        // because it depends on binary frameworks that can only be linked in the final app target

        ProtonCoreLog.PMLog.callback = { message, level in
            switch level {
            case .debug, .info, .trace, .warn:
                log.debug("\(message)", category: .core)
            case .error, .fatal:
                log.error("\(message)", category: .core)
            }
        }

        let apiService = networking.apiService
        do {
            let session = try await withTimeout(of: Self.sessionAcquisitionTimeout) {
                try await apiService.acquireSessionIfNeeded().get()
            }
            switch session {
            case let .sessionAlreadyPresent(credential), let .sessionFetchedAndAvailable(credential):
                if !credential.userID.isEmpty {
                    FeatureFlagsRepository.shared.setUserId(credential.userID)
                }

                TelemetryService.shared.setApiService(apiService: apiService)
                TelemetryService.shared.setTelemetryEnabled(telemetrySettings.telemetryUsageData)

                let isTelemetryEnabled = telemetrySettings.telemetryCrashReports

                if isTelemetryEnabled {
                    enableExternalLogging()
                } else {
                    disableExternalLogging()
                }
            case .sessionUnavailableAndNotFetched:
                log.error("acquireSessionIfNeeded didn't fetch a session, flag fetch may fail", category: .api, event: .response)
            }
        } catch {
            log.error("acquireSessionIfNeeded didn't succeed and therefore feature flags didn't get fetched", category: .api, event: .response, metadata: ["error": "\(error)"])
        }

        CheckedFeatureFlagsRepository.shared.setApiService(apiService)
        await CheckedFeatureFlagsRepository.shared.fetchFlags()

        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)
    }

    // MARK: - Telemetry

    private func enableExternalLogging() {
        @Dependency(\.dohConfiguration) var doh
        PMLog.setExternalLoggerHost(doh.defaultHost)
    }

    private func disableExternalLogging() {
        PMLog.disableExternalLogging()
    }

    private func registerForTelemetryChanges() {
        let center = NotificationCenter.default
        tokens.append(
            center.addObserver(for: AppEvent.telemetryCrashReports.name, object: nil) { [weak self] notification in
                let boolValue = notification.object as? Bool
                switch boolValue {
                case true:
                    self?.enableExternalLogging()
                case false:
                    self?.disableExternalLogging()
                default:
                    break // unknown object type, not doing anything
                }
            }
        )
    }

    // MARK: - Networking Events

    // TODO: We will move this to TCA reducer when it's time

    private func startObservingNetworkingEvents() {
        @Dependency(\.networkingDelegate) var networkingDelegate

        // Observe logout events (refresh token expired)
        Task {
            for await _ in networkingDelegate.logoutEvents {
                log.info("Refresh token expired, showing alert", category: .app)
                await handleLogout()
            }
        }

        // Observe force upgrade events
        Task {
            for await message in networkingDelegate.forceUpgradeEvents {
                log.info("Force upgrade required", category: .appUpdate, metadata: ["message": "\(message)"])
                await handleForceUpgrade(message: message)
            }
        }
    }

    @MainActor
    private func handleLogout() {
        let alertService = container.makeCoreAlertService()
        alertService.push(alert: RefreshTokenExpiredAlert())
    }

    @MainActor
    private func handleForceUpgrade(message: String) {
        let forceUpgradeService = ForceUpgradeHelper(config: .mobile(URL(string: URLConstants.appStoreUrl)!))
        forceUpgradeService.onForceUpgrade(message: message)
    }
}
