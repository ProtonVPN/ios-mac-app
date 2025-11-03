//
//  Created on 23/10/2024.
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

import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(Cocoa)
    import Cocoa
#endif

#if canImport(SystemExtensions)
    import SystemExtensions
#endif

import Dependencies
import Domain
import Strings

public protocol SystemAlert: AnyObject {
    var title: String? { get set }
    var message: String? { get set }
    var joinedTitleAndMessage: Bool { get }
    var actions: [AlertAction] { get set }
    var isError: Bool { get }
    var dismiss: (() -> Void)? { get set }
}

public extension SystemAlert {
    var joinedTitleAndMessage: Bool { false }
}

public enum PrimaryActionType {
    case confirmative
    case destructive
    case secondary
    case cancel
}

public struct AlertAction {
    public let title: String
    public let style: PrimaryActionType
    public let handler: (() -> Void)?

    public init(title: String, style: PrimaryActionType, handler: (() -> Void)?) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

public final class DomainErrorAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions: [AlertAction] = []
    public var isError = true
    public var dismiss: (() -> Void)?

    public init(alert: Domain.Alert) {
        self.title = String(localized: alert.title)
        self.message = String(localized: alert.message)
    }
}

public extension SystemAlert {
    static var className: String {
        String(describing: self)
    }

    var className: String {
        String(describing: type(of: self))
    }
}

public struct ReconnectInfo {
    public let fromServer: Server
    public let toServer: Server

    public struct Server {
        public let name: String

        #if canImport(UIKit)
            public let image: UIImage

            public init(name: String, image: UIImage) {
                self.name = name
                self.image = image
            }

        #elseif canImport(Cocoa)
            public let image: NSImage

            public init(name: String, image: NSImage) {
                self.name = name
                self.image = image
            }
        #endif
    }

    public init(fromServer: Server, toServer: Server) {
        self.fromServer = fromServer
        self.toServer = toServer
    }
}

public final class PaymentAlert: SystemAlert {
    public var title: String? = nil
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool
    public var dismiss: (() -> Void)?

    public init(message: String, isError: Bool) {
        self.message = message
        self.isError = isError
    }
}

public protocol UserAccountUpdateAlert: SystemAlert {
    var displayFeatures: Bool { get }
    var reconnectInfo: ReconnectInfo? { get set }
}

public protocol ExpandableSystemAlert: SystemAlert {
    var expandableInfo: String? { get set }
    var footInfo: String? { get set }
}

public final class AccountDeletionErrorAlert: SystemAlert {
    public var title: String? = Localizable.accountDeletionError
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(message: String) {
        self.message = message
    }
}

public final class AccountDeletionWarningAlert: SystemAlert {
    public var title: String? = Localizable.vpnConnectionActive
    public var message: String? = Localizable.accountDeletionConnectionWarning
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

/// App should update to be able to use API
public final class AppUpdateRequiredAlert: SystemAlert {
    public var title: String? = Localizable.updateRequired
    public var message: String? = Localizable.updateRequiredNoLongerSupported
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(_ error: Error) {
        self.message = error.localizedDescription
    }
}

public final class CannotAccessVpnCredentialsAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class P2pBlockedAlert: SystemAlert {
    public var title: String? = Localizable.p2pDetectedPopupTitle
    public var message: String? = Localizable.p2pDetectedPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class P2pForwardedAlert: SystemAlert {
    public var title: String? = Localizable.p2pForwardedPopupTitle
    public var message: String? = Localizable.p2pForwardedPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class RefreshTokenExpiredAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class UpgradeUnavailableAlert: SystemAlert {
    public var title: String? = Localizable.upgradeUnavailableTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(message: String? = nil, accountDashboardURL url: URL? = nil) {
        self.message = message ?? Localizable.upgradeUnavailableBody

        actions.append(AlertAction(title: Localizable.account, style: .confirmative) {
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url ?? VPNLink.accountDashboard.url)
        })
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

public final class UpgradeCreateAccountAlert: SystemAlert {
    public var title: String? = Localizable.createAccountFirstBeforeUpgrade
    public var message: String?
    public var actions: [AlertAction] = []
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(handler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.ok, style: .cancel, handler: handler))
    }
}

public final class DelinquentUserAlert: SystemAlert {
    public var title: String? = Localizable.delinquentUserTitle
    public var message: String? = Localizable.delinquentUserDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class VpnStuckAlert: SystemAlert {
    public var title: String? = Localizable.vpnStuckDisconnectingTitle
    public var message: String? = Localizable.vpnStuckDisconnectingBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class VpnNetworkUnreachableAlert: SystemAlert {
    public var title: String? = Localizable.notConnectedToTheInternet
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class MaintenanceAlert: SystemAlert {
    public var title: String? = Localizable.allServersInProfileUnderMaintenance
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    public let type: MaintenanceAlertType

    public init() {
        self.title = Localizable.allServersInProfileUnderMaintenance
        self.type = .alert
    }

    public init(countryName: String) {
        self.title = Localizable.countryServersUnderMaintenance(countryName)
        self.type = .alert
    }

    public init(cityName: String) {
        self.title = Localizable.countryServersUnderMaintenance(cityName)
        self.type = .alert
    }

    /// If `forSpecificCountry` is set, switches between country and servers texts, if it's nil, uses one text
    public init(forSpecificCountry: Bool?) {
        if let forSpecificCountry {
            self.title = forSpecificCountry ? Localizable.allServersInCountryUnderMaintenance : Localizable.allServersUnderMaintenance
        } else {
            self.title = Localizable.serverUnderMaintenance
        }
        self.type = .notification
    }

    public enum MaintenanceAlertType {
        case alert
        case notification
    }
}

public final class SecureCoreToggleDisconnectAlert: SystemAlert {
    public var title: String? = Localizable.warning
    public var message: String? = Localizable.viewToggleWillCauseDisconnect
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public final class ChangeProtocolDisconnectAlert: SystemAlert {
    public var title: String? = Localizable.vpnConnectionActive
    public var message: String? = Localizable.changeProtocolDisconnectWarning
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: dismiss))
    }
}

public final class ProtocolNotAvailableForServerAlert: SystemAlert {
    public var title: String? = Localizable.vpnProtocolNotSupportedTitle
    public var message: String? = Localizable.vpnProtocolNotSupportedText
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: (() -> Void)? = nil, cancelHandler: (() -> Void)? = nil) {
        if let confirmHandler {
            actions.append(AlertAction(
                title: Localizable.disconnect,
                style: .destructive,
                handler: confirmHandler
            ))
        }
        let dismissText = confirmHandler == nil ? Localizable.ok : Localizable.cancel
        actions.append(AlertAction(
            title: dismissText,
            style: .cancel,
            handler: cancelHandler ?? dismiss
        ))
    }
}

public final class LocationNotAvailableAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    /// Switching the title and message according to the presence of profileName.
    public init(profileName: String? = nil, confirmHandler: (() -> Void)? = nil, cancelHandler: (() -> Void)? = nil) {
        if let confirmHandler {
            actions.append(AlertAction(
                title: Localizable.disconnect,
                style: .destructive,
                handler: confirmHandler
            ))
        }
        let dismissText = confirmHandler == nil ? Localizable.ok : Localizable.cancel
        actions.append(AlertAction(
            title: dismissText,
            style: .cancel,
            handler: cancelHandler ?? dismiss
        ))
        self.dismiss = cancelHandler

        if let profileName {
            self.title = Localizable.locationNotAvailableForProfileTitle
            self.message = Localizable.locationNotAvailableForProfileText(profileName)
        } else {
            self.title = Localizable.locationNotAvailableTitle
            self.message = Localizable.locationNotAvailableText
        }
    }
}

public final class IKEv2PlutoniumConflictAlert: SystemAlert {
    public var title: String? {
        get {
            if let name = profileName {
                Localizable.splitTunnelingConnectToProfileNameAlertTitle(name)
            } else {
                Localizable.splitTunnelingConnectToProfileAlertTitle
            }
        }
        set {}
    }

    var profileName: String?
    public var message: String? = Localizable.splitTunnelingConnectToProfileAlertDescription
    public let linkText: String = Localizable.splitTunnelingConnectToProfileAlertLink

    public var actions: [AlertAction] = []
    public var isError: Bool = true

    public let dismissTitle = Localizable.cancel
    public var dismiss: (() -> Void)?

    public let disablePlutoniumTitle = Localizable.connect
    public let disablePlutoniumHandler: () -> Void

    public init(profileName: String?, disablePlutoniumHandler: @escaping (() -> Void)) {
        self.profileName = profileName
        self.disablePlutoniumHandler = disablePlutoniumHandler
    }
}

public final class ProtocolDeprecatedAlert: SystemAlert {
    public var title: String? = Localizable.alertProtocolDeprecatedTitle
    public let linkText: String = Localizable.alertProtocolDeprecatedLinkText

    #if os(iOS) || os(tvOS)
        public var message: String? = Localizable.alertProtocolDeprecatedBodyIos
    #elseif os(macOS)
        public var message: String? = Localizable.alertProtocolDeprecatedBodyMacos
    #endif

    public let confirmTitle: String = Localizable.alertProtocolDeprecatedEnableSmart
    public let dismissTitle: String = Localizable.alertProtocolDeprecatedClose

    public var actions = [AlertAction]()
    public let isError: Bool = true
    public let enableSmartProtocol: () -> Void
    public var dismiss: (() -> Void)?

    public init(enableSmartProtocolHandler: @escaping (() -> Void)) {
        self.enableSmartProtocol = enableSmartProtocolHandler

        actions.append(AlertAction(
            title: Localizable.alertProtocolDeprecatedEnableSmart,
            style: .confirmative,
            handler: enableSmartProtocolHandler
        ))
        #if os(iOS)
            // On MacOS, a hyperlink is placed in the alert body instead
            actions.append(AlertAction(
                title: Localizable.alertProtocolDeprecatedLearnMore,
                style: .secondary,
                handler: {
                    @Dependency(\.linkOpener) var linkOpener
                    linkOpener.open(.protocolDeprecations)
                }
            ))
        #endif
        actions.append(AlertAction(
            title: Localizable.alertProtocolDeprecatedClose,
            style: .cancel,
            handler: {}
        ))
    }
}

public final class ReconnectOnSettingsChangeAlert: SystemAlert {
    public struct UserCancelledReconnect: Error, CustomStringConvertible {
        public let description = "User was changing settings, but cancelled reconnecting."
    }

    public static let userCancelled = UserCancelledReconnect()

    public var title: String? = Localizable.changeSettings
    public var message: String? = Localizable.reconnectOnSettingsChangeBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public final class ReconnectOnActionAlert: SystemAlert {
    public var title: String?
    public var message: String? = Localizable.actionRequiresReconnect
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(actionTitle: String, confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        self.title = actionTitle
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public final class KillSwitchConflictAlert: SystemAlert {
    public var title: String? = Localizable.turnKsOnTitle
    #if os(iOS)
        public var message: String? = Localizable.turnKsOnDescriptionIos
    #else
        public var message: String? {
            get {
                if VPNFeatureFlagType.plutoniumMacOS.enabled {
                    Localizable.turnKsOnDescriptionMacosStConflict + "\n" + Localizable.turnKsOnDescriptionMacosLanConflict
                } else {
                    Localizable.turnKsOnDescriptionMacosLanConflict
                }
            }
            set {}
        }
    #endif
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.notNow, style: .cancel, handler: cancelHandler))
    }
}

public final class LANConnectionsKillSwitchConflictAlert: SystemAlert {
    public var title: String? = Localizable.allowLanTitle
    public var message: String? = Localizable.allowLanDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(connected: Bool, confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        if connected {
            message! += "\n\n" + Localizable.allowLanNote
        }
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.notNow, style: .cancel, handler: cancelHandler))
    }
}

public final class ReconnectOnSmartProtocolChangeAlert: SystemAlert {
    public struct UserCancelledReconnect: Error, CustomStringConvertible {
        public let description = "User selected smart protocol, but cancelled reconnecting."
    }

    public static let userCancelled = UserCancelledReconnect()

    public var title: String? = Localizable.smartProtocolReconnectModalTitle
    public var message: String? = Localizable.smartProtocolReconnectModalBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class LogoutWarningAlert: SystemAlert {
    public var title: String? = Localizable.vpnConnectionActive
    public var message: String? = Localizable.logOutWarning
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

public final class LogoutWarningLongAlert: LogoutWarningAlert {
    override public init(confirmHandler: @escaping () -> Void) {
        super.init(confirmHandler: confirmHandler)
        message = Localizable.logOutWarningLong
    }
}

public final class BugReportSentAlert: SystemAlert {
    public var title: String? = ""
    public var message: String? = Localizable.reportSuccess
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: confirmHandler))
    }
}

public final class ReportBugAlert: SystemAlert {
    public var title: String? = Localizable.errorUnknownTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class MITMAlert: SystemAlert {
    public enum MessageType {
        case api
        case vpn
    }

    public var title: String? = Localizable.errorMitmTitle
    public var message: String? = Localizable.errorMitmDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(messageType: MessageType = .api) {
        switch messageType {
        case .api:
            self.message = Localizable.errorMitmDescription
        case .vpn:
            self.message = Localizable.errorMitmVpnDescription
        }
    }
}

public final class UnreachableNetworkAlert: SystemAlert {
    public var title: String? = Localizable.warning
    public var message: String? = Localizable.neUnableToConnectToHost
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(error: Error, troubleshoot: @escaping () -> Void) {
        self.message = error.localizedDescription
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
        actions.append(AlertAction(title: Localizable.neTroubleshoot, style: .confirmative, handler: troubleshoot))
    }
}

public final class ConnectionTroubleshootingAlert: SystemAlert {
    public var title: String? = Localizable.errorUnknownTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class VpnServerOnMaintenanceAlert: SystemAlert {
    public var title: String? = Localizable.maintenanceOnServerDetectedTitle
    public var message: String? = Localizable.maintenanceOnServerDetectedDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class ReconnectOnNetshieldChangeAlert: SystemAlert {
    public var title: String? = Localizable.reconnectionRequired
    public var message: String? = Localizable.netshieldAlertReconnectDescriptionOn
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(isOn: Bool, continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        self.message = isOn ? Localizable.netshieldAlertReconnectDescriptionOn : Localizable.netshieldAlertReconnectDescriptionOff
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public final class NetShieldRequiresUpgradeAlert: SystemAlert {
    public var title: String? = Localizable.upgradeRequired
    public var message: String? = Localizable.netshieldAlertUpgradeDescription + "\n\n" + Localizable.getPlusForFeature
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.upgrade, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public final class VPNAuthCertificateRefreshErrorAlert: SystemAlert {
    public var title: String? = Localizable.vpnauthCertfailTitle
    public var message: String? = Localizable.vpnauthCertfailDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class UserPlanDowngradedAlert: UserAccountUpdateAlert {
    public var imageName: String?
    public var displayFeatures: Bool = true
    public var title: String? = Localizable.subscriptionExpiredTitle
    public var message: String? = Localizable.subscriptionExpiredDescription
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?
    public var reconnectInfo: ReconnectInfo?

    public init(reconnectInfo: ReconnectInfo?) {
        actions.append(AlertAction(title: Localizable.upgradeAgain, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: Localizable.noThanks, style: .cancel, handler: nil))
        self.reconnectInfo = reconnectInfo
        if reconnectInfo != nil {
            self.message = Localizable.subscriptionExpiredReconnectionDescription
        }
    }
}

public final class UserBecameDelinquentAlert: UserAccountUpdateAlert {
    public var imageName: String?
    public var displayFeatures: Bool = false
    public var reconnectInfo: ReconnectInfo?
    public var title: String? = Localizable.delinquentTitle
    public var message: String? = Localizable.delinquentDescription
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(reconnectInfo: ReconnectInfo?) {
        actions.append(AlertAction(title: Localizable.updateBilling, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: Localizable.noThanks, style: .cancel, handler: nil))
        self.reconnectInfo = reconnectInfo
        if reconnectInfo != nil {
            self.message = Localizable.delinquentReconnectionDescription
        }
    }
}

public final class VpnServerErrorAlert: SystemAlert {
    public var title: String? = Localizable.localAgentServerErrorTitle
    public var message: String? = Localizable.localAgentServerErrorMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class VpnServerSubscriptionErrorAlert: SystemAlert {
    public var title: String? = Localizable.localAgentPolicyViolationErrorTitle
    public var message: String? = Localizable.localAgentPolicyViolationErrorMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class DiscourageSecureCoreAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var onDontShowAgain: ((Bool) -> Void)?
    public var onActivate: (() -> Void)?
    public var onLearnMore: (() -> Void) = {
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(.learnMore)
    }

    public var dismiss: (() -> Void)?

    public init() {}
}

public final class SubuserWithoutConnectionsAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public let mode: NoConnectionsAvailableMode

    public init(mode: NoConnectionsAvailableMode) {
        self.mode = mode
    }
}

public final class TooManyCertificateRequestsAlert: SystemAlert {
    public var title: String? = Localizable.vpnauthTooManyCertsTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(retryAfter: TimeInterval? = nil) {
        guard let retryAfter else {
            self.message = Localizable.vpnauthTooManyCertsDescription
            return
        }

        // If we get a retry interval, display a more helpful message to the user regarding how long they
        // should wait before trying again.
        let (_, hours, minutes, seconds) = retryAfter.components
        var minutesToWait = minutes
        if hours > 0 {
            minutesToWait += 60 * hours
        }
        if seconds > 0 {
            minutesToWait += 1
        }

        self.message = Localizable.vpnauthTooManyCertsRetryAfter(minutesToWait)
    }
}

public final class ProtonUnreachableAlert: SystemAlert {
    public var title: String?
    public var message: String? = Localizable.protonWebsiteUnreachable
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
}

public final class ConnectingWithBadLANAlert: SystemAlert {
    public var title: String? = Localizable.badInterfaceIpRangeAlertTitle
    public var message: String?

    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(
        badIpAndPrefix: String?,
        badInterfaceName: String?,
        killSwitchOnHandler: @escaping () -> Void,
        connectAnywayHandler: @escaping () -> Void
    ) {
        self.message = Localizable.promptKillSwitchDueToBadInterfaceIpRange(
            badInterfaceName ?? "Unknown Interface",
            badIpAndPrefix ?? "Unknown Subnet"
        )

        actions.append(contentsOf: [
            .init(title: Localizable.killSwitchEnable, style: .confirmative, handler: killSwitchOnHandler),
            .init(title: Localizable.continue, style: .destructive, handler: connectAnywayHandler),
        ])
    }
}

public final class UpgradeOperatingSystemAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions: [AlertAction]
    public var isError = false
    public var dismiss: (() -> Void)?

    public init(minimumOSVersionRequired version: OperatingSystemVersion) {
        let platform: String

        #if os(iOS)
            platform = "iOS"
        #elseif os(macOS)
            platform = "macOS"
        #elseif os(tvOS)
            platform = "tvOS"
        #elseif os(visionOS)
            platform = "visionOS"
        #else
            platform = "Unrecognized"
        #endif

        self.title = Localizable.operatingSystemOutOfDateAlertTitle
        self.message = Localizable.operatingSystemOutOfDateAlertDescription(platform, version.osVersionString)
        self.actions = [
            .init(title: Localizable.gotIt, style: .confirmative, handler: nil),
        ]
    }
}

public final class MaxSessionsAlert: UserAccountUpdateAlert {
    public var reconnectInfo: ReconnectInfo?
    public var displayFeatures: Bool = false
    public var title: String? = Localizable.maximumDeviceTitle
    public var message: String?
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?
    public var accountTier: Int

    public init(accountTier: Int) {
        self.accountTier = accountTier
        if accountTier.isFreeTier {
            self.message = Localizable.maximumDevicePlanLimitPart1(Localizable.tierPlus)
                + Localizable.maximumDevicePlanLimitPart2(DomainConstants.maxDeviceCount)
        } else {
            self.message = Localizable.maximumDeviceReachedDescription
        }

        actions.append(AlertAction(title: Localizable.upgrade, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: Localizable.noThanks, style: .cancel, handler: nil))
    }
}

/// Warns the user the signing in while connected requires them to be disconnected first.
public final class DisconnectToSignInAlert: SystemAlert {
    public var title: String? = Localizable.disconnectRequired
    public var message: String? = Localizable.disconnectToSignInDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.actionDisconnect, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

/// Shown when the user must perform an action to authenticate themselves to regain VPN connectivity
// TODO: Localize this alert
public final class TwoFactorAuthenticationRequiredAlert: SystemAlert {
    public var title: String? = "2FA Required"
    public var message: String? = """
    You are connected to the VPN, but all traffic is blocked.
    You need to go to the authentication page provided by security and authenticate with your hardware key.
    After that the traffic will be enabled.
    """
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(
        openTFAHandler: @escaping () -> Void,
        disconnectHandler: (() -> Void)? = nil
    ) {
        actions.append(AlertAction(title: "Open 2FA", style: .confirmative, handler: openTFAHandler))
        actions.append(AlertAction(title: Localizable.actionDisconnect, style: .cancel, handler: disconnectHandler))
    }
}

#if canImport(SystemExtensions)
    public final class SysexEnabledAlert: SystemAlert {
        public var title: String? = Localizable.sysexEnabledTitle
        public var message: String? = Localizable.sysexEnabledDescription
        public var actions = [AlertAction]()
        public let isError: Bool = false
        public var dismiss: (() -> Void)?

        public init() {}
    }

    @available(macOS 13, iOS 18.4, *)
    public final class SysexInstallingErrorAlert: SystemAlert {
        public var title: String? = Localizable.sysexCannotEnable
        public var message: String?
        public var actions = [AlertAction]()
        public let isError: Bool = true
        public var dismiss: (() -> Void)?

        public init?(error: Error) {
            guard let sysexError = error as? OSSystemExtensionError else {
                return nil
            }

            let subcase: String = switch sysexError.code {
            case .unsupportedParentBundleLocation:
                Localizable.sysexErrorDescriptionSubcaseBadLocation
            case .forbiddenBySystemPolicy:
                Localizable.sysexErrorDescriptionSubcaseForbiddenBySystemPolicy
            case .authorizationRequired:
                Localizable.sysexErrorDescriptionSubcaseAuthorizationRequired
            case .codeSignatureInvalid:
                Localizable.sysexErrorDescriptionSubcaseCodeSignatureInvalid
            default:
                Localizable.sysexErrorDescriptionSubcaseDefault(sysexError.code.errorCodeString)
            }

            self.message = Localizable.sysexErrorDescription(subcase)

            actions.append(AlertAction(title: Localizable.ok, style: .cancel, handler: nil))
        }
    }

    public final class SystemExtensionTourAlert: SystemAlert {
        public var title: String?
        public var message: String?
        public var actions = [AlertAction]()
        public let isError: Bool = false
        public var dismiss: (() -> Void)?
        public var cancelHandler: () -> Void

        public let origin: Origin

        public enum Origin {
            case firstAppLaunch
            case inAppPrompt([Feature])
        }

        public enum Feature: CaseIterable {
            case wireguard
            case splitTunneling
        }

        public init(origin: Origin, cancelHandler: @escaping () -> Void) {
            self.cancelHandler = cancelHandler
            self.dismiss = cancelHandler
            self.origin = origin
        }
    }
#endif
