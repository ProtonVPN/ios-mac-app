//
//  AppDelegate.swift
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

import AppKit

// System frameworks
import Cocoa
import ServiceManagement

// Third-party dependencies
#if DEBUG
    import Atlantis
#endif
import Dependencies
import TrustKit

import ProtonCoreCryptoVPNPatchedGoImplementation
import ProtonCoreEnvironment
import ProtonCoreFeatureFlags
import ProtonCoreLog
import ProtonCoreObservability
import ProtonCorePushNotifications

// Core dependencies
import ProtonCoreServices
import ProtonCoreUIFoundations

import Announcement
import Domain
import Ergonomics
import Sharing

// Local dependencies (Core first, then Shared, then Features, then Foundations)
import LegacyCommon
import Logging
import PMLogger
import Settings
import Timer
import VPNAppCore
import VPNShared

#if !REDESIGN

    let log: Logging.Logger = .init(label: "ProtonVPN.logger")

    class AppDelegate: NSObject {
        @IBOutlet var protonVpnMenu: ProtonVpnMenuController!
        @IBOutlet var profilesMenu: ProfilesMenuController!
        @IBOutlet var helpMenu: HelpMenuController!
        @IBOutlet var statusMenu: StatusMenuWindowController!

        let container = DependencyContainer()
        lazy var navigationService = container.makeNavigationService()
        @Dependency(\.propertiesManager) private var propertiesManager
        @Dependency(\.authKeychain) private var authKeychain
        @Dependency(\.vpnKeychain) private var vpnKeychain
        @Dependency(\.networking) private var networking
        @Dependency(\.appInfo) private var appInfo
        private var appInactivityTask: Task<Void, Error>?
        private lazy var pushNotificationService = PushNotificationService.shared
        private var notificationManager: NotificationManagerProtocol!
        private lazy var telemetrySettings: TelemetrySettings = container.makeTelemetrySettings()

        private var tokens: [NotificationToken] = []

        @Dependency(\.defaultsProvider) private var provider
        public private(set) static var wasRecentlyActive = false
        private var appHasCompletedInitialSetup: Bool = false
    }
#else
    class AppDelegate: NSObject {
        @Dependency(\.defaultsProvider) var provider
        public private(set) static var wasRecentlyActive = false
        let container = DependencyContainer()
        lazy var navigationService = container.makeNavigationService()
        @Dependency(\.propertiesManager) private var propertiesManager
        @Dependency(\.appInfo) private var appInfo
        private var appInactivityTask: Task<Void, Error>?
        private lazy var pushNotificationService = PushNotificationService.shared
        private var notificationManager: NotificationManagerProtocol!
    }
#endif

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        setupLogsForApp()
        log.debug("applicationDidFinishLaunching", category: .app)

        NSApp.appearance = .init(named: .darkAqua)
        injectDefaultCryptoImplementation()

        #if DEBUG
            Atlantis.start()
        #endif

        // Clear out any overrides that may have been present in previous builds
        FeatureFlagsRepository.shared.resetOverrides()

        for (featureFlagOverride, value) in propertiesManager.featureFlagOverrides ?? [:] {
            guard let feature = ManuallySpecifiedFeatureFlag(rawValue: featureFlagOverride) else { continue }
            FeatureFlagsRepository.shared.setFlagOverride(feature, value)
        }

        Task {
            // wait for feature flags to be fetched
            await setupCoreIntegration()
            // Continue with the rest of the initialization after setupCoreIntegration completes
            await MainActor.run {
                log.info("Starting app version \(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))", category: .app, event: .processStart)

                AppStartup.processStartAppleEvent()

                LegacyDefaultsMigration.migrateLargeData(from: provider.getDefaults())

                // Ignore SIGPIPE errors, which can happen when receiving mach messages or writing to sockets.
                signal(SIGPIPE, SIG_IGN)

                checkMigration()
                setNSCodingModuleName()
                setupDebugHelpers()

                SentryHelper.setupSentry(
                    dsn: ObfuscatedConstants.sentryDsnmacOS,
                    isEnabled: { [weak self] in
                        self?.isTelemetryAllowed() ?? false
                    },
                    getUserId: { [weak self] in
                        self?.authKeychain.userId
                    }
                )

                AppLaunchRoutine.execute()
                #if !REDESIGN
                    protonVpnMenu.update(with: container.makeProtonVpnMenuViewModel())
                    profilesMenu.update(with: container.makeProfilesMenuViewModel())
                    helpMenu.update(with: container.makeHelpMenuViewModel())
                    statusMenu.update(with: container.makeStatusMenuWindowModel())
                    container.makeWindowService().setStatusMenuWindowController(self.statusMenu)
                #endif
                notificationManager = container.makeNotificationManager()
                container.makeMaintenanceManagerHelper().startMaintenanceManager()
                _ = container.makeUpdateManager() // Load update manager so it has a chance to update xml url
                _ = container.makeDynamicBugReportManager() // Loads initial bug report config and sets up a timer to refresh it daily.

                if startedAtLogin() {
                    DistributedNotificationCenter.default().post(name: Notification.Name("killMe"), object: Bundle.main.bundleIdentifier!)
                }

                // Check sysex approval and protocol deprecation and revert to Smart or IKE if necessary, but only if we're logged in
                if (try? vpnKeychain.fetchCached()) != nil {
                    checkSysexAndAdjustGlobalProtocol()
                }
            }

            // run it in a syncrhonous way
            await Task { @MainActor in
                await self.container.makeVpnManager().prepareManagersTask?.value
                await self.navigationService.launched()
            }.value

            await MainActor.run {
                registerForTelemetryChanges()

                container.applicationDidFinishLaunching()
                // because of much async work we have to ensure that we initialised everything
                appHasCompletedInitialSetup = true
            }
        }

        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(getUrl(_:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc
    private func getUrl(_ event: NSAppleEventDescriptor, withReplyEvent _: NSAppleEventDescriptor) {
        guard let url = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, url.starts(with: "protonvpn://refresh") else {
            log.debug("App activated with invalid url", category: .app)
            return
        }

        log.debug("App activated with the refresh url, refreshing data", category: .app, metadata: ["url": "\(url)"])
        guard authKeychain.username != nil else {
            log.debug("User not is logged in, not refreshing user data", category: .app)
            return
        }

        Task {
            log.debug("User is logged in, refreshing user data", category: .app)
            do {
                try await container.makeAppSessionManager().attemptSilentLogIn()
                log.debug("User data refreshed after url activation", category: .app)
            } catch {
                log.error("User data failed to refresh after url activation", category: .app, metadata: ["error": "\(error)"])
            }

            AppEvent.urlActivationRefresh.post()
        }
    }

    private func setupDebugHelpers() {
        #if DEBUG
            CertificateConstants.certificateDuration = "10 minutes"
        #endif
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // This is called during app start, but we don't want to show any windows/screens etc
        // before everything is initialised in applicationDidFinishLaunching
        guard appHasCompletedInitialSetup else { return false }
        return navigationService.handleApplicationReopen(hasVisibleWindows: flag)
    }

    func applicationDidBecomeActive(_: Notification) {
        log.info("applicationDidBecomeActive", category: .os)
        updateRecentlyActive(true)

        // Refresh API announcements
        @Dependency(\.announcementRefresher) var announcementRefresher: AnnouncementRefresher
        if propertiesManager.featureFlags.pollNotificationAPI, authKeychain.username != nil {
            announcementRefresher.tryRefreshing()
        }
    }

    func applicationDidResignActive(_: Notification) {
        log.info("applicationDidResignActive", category: .os)

        updateRecentlyActive(false)
    }

    /// Waits until the app has been inactive for the specified interval, then sets ``wasRecentlyActive`` to `false` on
    /// `AppDelegate`. This is used for the ``AppSessionRefreshTimer`` to decide how often to update certain info.
    func updateRecentlyActive(_ active: Bool) {
        appInactivityTask?.cancel()
        appInactivityTask = nil

        if active {
            Self.wasRecentlyActive = true
        } else {
            @Dependency(\.continuousClock) var clock
            appInactivityTask = Task { @MainActor in
                try await clock.sleep(for: .seconds(AppConstants.Time.recentlyActiveThreshold), tolerance: .seconds(1))
                try Task.checkCancellation()
                Self.wasRecentlyActive = false
            }
        }
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        log.info("applicationShouldTerminate", category: .os)
        provider.getDefaults().set(500, forKey: "NSInitialToolTipDelay")
        return navigationService.handleApplicationShouldTerminate()
    }

    private func checkSysexAndAdjustGlobalProtocol() {
        let connectionProtocol = propertiesManager.connectionProtocol
        if connectionProtocol.isDeprecated {
            // At this time on MacOS, OpenVPN is the only deprecated protocol, and it requires sysex approval, so can
            // safely fall back to smart protocol.
            propertiesManager.connectionProtocol = .smartProtocol
        }

        // For new installations, we also ask for plutonium extension installation.
        let includedExtensionTypes: [SystemExtensionType] = propertiesManager.isSubsequentLaunch ? [.wireGuard] : [.wireGuard, .plutonium]

        container
            .makeSystemExtensionManager()
            .installOrUpdateExtensionsIfNeeded(shouldStartTour: true, includedTypes: includedExtensionTypes) { _, individualResults in
                // Check WireGuard installation for protocol fallback logic
                if let wireGuardResult = individualResults[.wireGuard] {
                    switch wireGuardResult {
                    case let .success(success):
                        switch success {
                        case .installed, .upgraded:
                            // Switch away from ike to smart protocol if wireGuard succeeded.
                            if self.propertiesManager.connectionProtocol == .vpnProtocol(.ike) {
                                self.propertiesManager.connectionProtocol = .smartProtocol
                            }
                        case .alreadyThere:
                            break
                        }
                    case .failure:
                        // Either we lost sysex approval, or are upgrading from an earlier version which didn't have this check
                        log.warning("\(self.propertiesManager.connectionProtocol) requires sysex (WireGuard not installed), reverting to IKEv2", category: .sysex)
                        self.propertiesManager.connectionProtocol = .vpnProtocol(.ike)
                        @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
                        log.debug("Disabling Plutonium feature because the WireGuard extension is not installed.")
                        $feature.withLock {
                            $0.disable()
                        }
                    }
                }

                // Check Plutonium installation and log if it failed
                if let plutoniumResult = individualResults[.plutonium] {
                    switch plutoniumResult {
                    case .success:
                        log.info("Plutonium extension installed successfully", category: .sysex)
                    case let .failure(error):
                        log.warning("Plutonium extension installation failed: \(error)", category: .sysex)
                        @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
                        log.debug("Disabling Plutonium feature because the system extension is not installed.")
                        $feature.withLock {
                            $0.disable()
                        }
                    }
                }
            }
    }

    private func setNSCodingModuleName() {
        // Force all encoded objects to be decoded and encoded using the ProtonVPN module name
        setUpNSCoding(withModuleName: "ProtonVPN")
    }

    private func startedAtLogin() -> Bool {
        let launcherAppIdentifier = "ch.protonvpn.ProtonVPNStarter"
        for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == launcherAppIdentifier {
            return true
        }
        return false
    }

    private func setupLogsForApp() {
        @Dependency(\.logFileManager) var logFileManager
        let logFile = logFileManager.getFileUrl(named: AppConstants.Filenames.appLogFilename)

        let fileLogHandler = FileLogHandler(logFile)
        let osLogHandler = OSLogHandler(formatter: OSLogFormatter())
        let multiplexLogHandler = MultiplexLogHandler([osLogHandler, fileLogHandler])

        LoggingSystem.bootstrap { _ in multiplexLogHandler }
    }

    private func isTelemetryAllowed() -> Bool {
        container.makeTelemetrySettings().telemetryCrashReports
    }
}

// MARK: - Migration

extension AppDelegate {
    private func checkMigration() {
        container.makeMigrationManager()
            .addCheck("1.7.1") { version, completion in
                // Restart the connection, because whole vpncore was upgraded between version 1.6.0 and 1.7.0
                log.info("App was updated to version 1.7.1 from version \(version)", category: .appUpdate)

                self.reconnectWhenPossible()
                completion(nil)
            }
            .addCheck("2.0.0") { [propertiesManager] version, completion in
                // Restart the connection, to enable native KS (if needed)
                log.info("App was updated to version 2.0.0 from version \(version)", category: .appUpdate)

                guard propertiesManager.killSwitch else {
                    completion(nil)
                    return
                }

                self.reconnectWhenPossible()
                completion(nil)
            }
            .migrate { _ in
                // Migration complete
            }
    }

    private func reconnectWhenPossible() {
        var appStateManager = container.makeAppStateManager()

        appStateManager.onVpnStateChanged = { newState in
            if newState != .invalid {
                appStateManager.onVpnStateChanged = nil
            }

            guard case .connected = newState else {
                return
            }

            appStateManager.disconnect {
                self.container.makeVpnGateway().quickConnect(trigger: .auto)
            }
        }
    }
}

extension AppDelegate {
    // Typically set the environment only if telemetry is allowed
    private func enableExternalLogging() {
        @Dependency(\.dohConfiguration) var doh
        PMLog.setExternalLoggerHost(doh.defaultHost)
    }

    private func disableExternalLogging() {
        PMLog.disableExternalLogging()
    }

    private func setupCoreIntegration() async {
        ColorProvider.brand = .vpn

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
            let session = try await apiService.acquireSessionIfNeeded().get()
            switch session {
            case let .sessionAlreadyPresent(authCredential), let .sessionFetchedAndAvailable(authCredential):
                FeatureFlagsRepository.shared.setApiService(apiService)
                if !authCredential.userID.isEmpty {
                    FeatureFlagsRepository.shared.setUserId(authCredential.userID)
                }

                await CheckedFeatureFlagsRepository.shared.fetchFlags()

                let isTelemetryEnabled = telemetrySettings.telemetryCrashReports

                if isTelemetryEnabled {
                    enableExternalLogging()
                } else {
                    disableExternalLogging()
                }
            default:
                break
            }
        } catch {
            log.error(
                "acquireSessionIfNeeded didn't succeed and therefore feature flags didn't get fetched",
                category: .api, event: .response, metadata: ["error": "\(error)"]
            )
        }
        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)
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
}
