//
//  Created on 14.02.2025 by John Biggs.
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
import IssueReporting

/// A set of in-app events that can happen asynchronously, posted and subscribed by many different components.
///
/// If it seems like a lot of these are redundant, it's because they probably are. These used to live in
/// multiple different objects but have been coalesced here so that they could be referenced without needing to
/// import the entire module that each object is part of.
///
/// - Note: wherever possible, try to use TCA events instead, since this relies on NotificationCenter.
public enum AppEvent: String {
    // MARK: Connection state

    /// The current active connection changed.
    case activeConnectionChanged
    /// The current active server type changed.
    case activeServerTypeChanged
    /// The connection state (generated from the current app state) changed.
    case connectionStateChanged
    /// The user has connected.
    case hasConnected
    /// The connection state has changed.
    case appStateManagerStateChange
    /// The display state for the current connection state has changed.
    case appStateManagerDisplayStateChange
    /// When a reconnect is necessary.
    case needsReconnect

    // MARK: User settings

    /// The user's kill switch setting has changed.
    case killSwitch
    /// The user's "exclude local networks" setting has changed.
    case excludeLocalNetworks
    /// The user's VPN protocol setting has changed.
    case vpnProtocol
    /// The user's smart protocol setting has changed.
    case smartProtocol
    /// The user's VPN accelerator setting has changed.
    case vpnAccelerator
    /// The user's netshield setting has changed.
    case netShield
    /// The user has changed their desired telemetry reporting preferences.
    case telemetryUsageData
    /// The user has changed their desired crash reporting preferences.
    case telemetryCrashReports
    /// The user's IP (outside of the VPN) has changed.
    case userIp
    /// The visible content in the profile settings has changed.
    case profileContentChanged
    /// The content on disk of profiles settings has changed.
    case profileStorageChanged
    /// The user's NAT type setting changed.
    case natType
    /// The user's safe mode setting changed.
    case safeMode
    /// The Hermes settings changed.
    case hermes
    /// The Plutonium settings changed.
    case plutonium
    /// The user's Auth credentials changed.
    case authCredentialsChanged

    // MARK: API-Driven

    /// New announcements are available.
    case announcementStorageContent
    /// The user's VPN credentials changed on the backend.
    case credentialsChanged
    /// The user's payment for their VPN plan is delinquent.
    case userDelinquent
    /// The user's VPN plan changed on the backend.
    case planChanged
    /// Some feature flags have changed from the backend.
    case featureFlags
    /// Session manager data was reloaded.
    case sessionManagerDataReloaded
    /// Session manager data has changed.
    case sessionManagerSessionChanged
    /// Session manager data has been refreshed.
    case sessionManagerSessionRefreshed

    // MARK: User events (mostly for Telemetry)

    /// The app has been opened through a deep-link by the website, and we need to refresh our data.
    case urlActivationRefresh
    /// A user initiated a change to the VPN configuration.
    case userInitiatedVPNChange
    /// An upsell alert was displayed due to a user clicking on a feature reserved for paid users.
    case upsellAlertWasDisplayed
    /// A user was upsold by clicking on a paid feature, and proceeded to the "Upgrade" step.
    case userEngagedWithUpsellAlert
    /// A user upgraded their plan - it's up to the TelemetryService to figure out if this was the result of an upsell.
    ///
    /// In the future it would be best to plumb the upsell result data through the payment portal so that we can know
    /// for sure if we made the payment roundtrip thanks to the upsell modal.
    case userCompletedUpsellAlertJourney
    /// A user was displayed a announcement.
    case userWasDisplayedAnnouncement
    /// A user was redirected to a payment portal through a notification.
    case userEngagedWithAnnouncement

    // MARK: Platform-Specific

    #if os(macOS)
        /// The `earlyAccess` value changed. This happens when a user wants to use the beta version of the app.
        case earlyAccess
        /// The user bailed out of the system extension tour early.
        case systemExtensionTourCancelled
        /// The user successfully installed all of the system extensions.
        case systemExtensionsAllInstalled
        /// A user has elected to clear all application data. (This happens by default on iOS when removing the app.)
        case clearingApplicationData
    #elseif os(iOS)
        /// The user dismissed the welcome screen.
        case userDismissedWelcomeScreen
    #endif

    #if DEBUG
        /// Used for unit and integration testing.
        case testEvent
    #endif

    private static let notificationSuffix: String = "VPNAppNotification"
    public var name: Notification.Name {
        .init(rawValue + Self.notificationSuffix) // Make sure we de-unique from other common names
    }

    public var publisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: name)
    }

    public func subscribe(_ object: Any, selector: Selector) {
        NotificationCenter.default.addObserver(object, selector: selector, name: name, object: nil)
    }

    public func subscribe(
        _ object: Any? = nil,
        queue: OperationQueue? = nil,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> any NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: name, object: object, queue: queue, using: block)
    }

    public func unsubscribe(_ object: Any) {
        NotificationCenter.default.removeObserver(object, name: name, object: nil)
    }

    /// Send the given event to any subsystem that might be listening.
    ///
    /// - Warning: if necessary, you are responsible for invoking this method on the main thread.
    public func post(_ object: Any? = nil, userInfo: [String: Any]? = nil) {
        NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
    }
}

/// Posted as a subcase of the `userInitiatedVPNChange` case in `AppEvent`. Used for telemetry.
public enum UserInitiatedVPNChange {
    public enum VPNTrigger: String, Codable, Sendable {
        case quick
        case connectionCard = "connection_card"
        case changeServer = "change_server"
        case recent
        case pin
        case countriesCountry = "countries_country"
        case countriesState = "countries_state"
        case countriesCity = "countries_city"
        case countriesServer = "countries_server"
        case searchCountry = "search_country"
        case searchState = "search_state"
        case searchCity = "search_city"
        case searchServer = "search_server"
        case gatewaysGateway = "gateways_gateway"
        case gatewaysServer = "gateways_server"
        case country
        case server
        case profile
        case map
        case tray
        case widget
        case auto
        case newConnection = "new_connection"
        case exit
        case signout
    }

    case connect(VPNTrigger?)
    case disconnect(VPNTrigger)
    case abort
    case settingsChange
    case logout
}

public extension AppEvent {
    init?(_ name: Notification.Name) {
        let rawValue = name.rawValue.hasSuffix(Self.notificationSuffix) ?
            String(name.rawValue.dropLast(Self.notificationSuffix.count)) :
            name.rawValue

        guard let value = Self(rawValue: rawValue) else {
            reportIssue("Expected AppEvent object with rawValue: \(rawValue), got nil")
            return nil
        }
        self = value
    }
}

public extension [AppEvent] {
    func subscribe(_ object: Any, selector: Selector) {
        for event in self {
            event.subscribe(object, selector: selector)
        }
    }
}
