//
//  AlertService.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings
import Dependencies
import Persistence
import VPNAppCore
import Ergonomics

public protocol CoreAlertServiceFactory {
    func makeCoreAlertService() -> CoreAlertService
}

public protocol CoreAlertService: AnyObject {
    func push(alert: SystemAlert)
}

public protocol UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService
}

public protocol UIAlertService: AnyObject {
    func displayAlert(_ alert: SystemAlert)
    func displayAlert(_ alert: SystemAlert, message: NSAttributedString)
    func displayNotificationStyleAlert(message: String, type: NotificationStyleAlertType, accessibilityIdentifier: String?)
}

// Add default value to `accessibilityIdentifier`
extension UIAlertService {
    func displayNotificationStyleAlert(message: String, type: NotificationStyleAlertType) {
        return displayNotificationStyleAlert(message: message, type: type, accessibilityIdentifier: nil)
    }
}

public enum NotificationStyleAlertType {
    case error
    case success
}

public struct ReconnectInfo {
    public let fromServer: Server
    public let toServer: Server

    public struct Server {
        public let name: String
        public let image: Image

        public init(name: String, image: Image) {
            self.name = name
            self.image = image
        }
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

extension SystemAlert {
    public static var className: String {
        return String(describing: self)
    }
    
    public var className: String {
        return String(describing: type(of: self))
    }
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
        message = error.localizedDescription
    }
}

public final class CannotAccessVpnCredentialsAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public final class P2pBlockedAlert: SystemAlert {
    public var title: String? = Localizable.p2pDetectedPopupTitle
    public var message: String? = Localizable.p2pDetectedPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public final class P2pForwardedAlert: SystemAlert {
    public var title: String? = Localizable.p2pForwardedPopupTitle
    public var message: String? = Localizable.p2pForwardedPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public final class RefreshTokenExpiredAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public final class UpgradeUnavailableAlert: SystemAlert {
    public var title: String? = Localizable.upgradeUnavailableTitle
    public var message: String? = Localizable.upgradeUnavailableBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {
        let confirmHandler: () -> Void = {
            SafariService().open(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
        }
        actions.append(AlertAction(title: Localizable.account, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

public final class DelinquentUserAlert: SystemAlert {
    public var title: String? = Localizable.delinquentUserTitle
    public var message: String? = Localizable.delinquentUserDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() { }
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
}

public final class MaintenanceAlert: SystemAlert {
    public var title: String? = Localizable.allServersInProfileUnderMaintenance
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    public let type: MaintenanceAlertType
    
    public init() {
        title = Localizable.allServersInProfileUnderMaintenance
        type = .alert
    }
    
    public init(countryName: String) {
        title = Localizable.countryServersUnderMaintenance(countryName)
        type = .alert
    }

    public init(cityName: String) {
        title = Localizable.countryServersUnderMaintenance(cityName)
        type = .alert
    }
    
    /// If `forSpecificCountry` is set, switches between country and servers texts, if it's nil, uses one text
    public init(forSpecificCountry: Bool?) {
        if let forSpecificCountry = forSpecificCountry {
            title = forSpecificCountry ? Localizable.allServersInCountryUnderMaintenance : Localizable.allServersUnderMaintenance
        } else {
            title = Localizable.serverUnderMaintenance
        }
        type = .notification
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
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.settingsChange)
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
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.settingsChange)
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
            actions.append(AlertAction(title: Localizable.disconnect,
                                       style: .destructive,
                                       handler: confirmHandler))
        }
        let dismissText = confirmHandler == nil ? Localizable.ok : Localizable.cancel
        actions.append(AlertAction(title: dismissText,
                                   style: .cancel,
                                   handler: cancelHandler ?? dismiss))
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
            actions.append(AlertAction(title: Localizable.disconnect,
                                       style: .destructive,
                                       handler: confirmHandler))
        }
        let dismissText = confirmHandler == nil ? Localizable.ok : Localizable.cancel
        actions.append(AlertAction(title: dismissText,
                                   style: .cancel,
                                   handler: cancelHandler ?? dismiss))
        dismiss = cancelHandler

        if let profileName {
            title = Localizable.locationNotAvailableForProfileTitle
            message = Localizable.locationNotAvailableForProfileText(profileName)
        } else {
            title = Localizable.locationNotAvailableTitle
            message = Localizable.locationNotAvailableText
        }
    }
}

public final class ProtocolDeprecatedAlert: SystemAlert {
    public var title: String? = Localizable.alertProtocolDeprecatedTitle
    public let linkText: String = Localizable.alertProtocolDeprecatedLinkText

    #if os(iOS)
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

    public static let kbURLString = "https://protonvpn.com/blog/remove-vpn-protocols-apple"

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
            handler: { SafariService.openLink(url: URL(string: Self.kbURLString)!) }
        ))
        #endif
        actions.append(AlertAction(
            title: Localizable.alertProtocolDeprecatedClose,
            style: .cancel,
            handler: { }
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
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.settingsChange)
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
        title = actionTitle
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public final class TurnOnKillSwitchAlert: SystemAlert {
    public var title: String? = Localizable.turnKsOnTitle
    public var message: String? = Localizable.turnKsOnDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.settingsChange)
            confirmHandler()
        }))
        actions.append(AlertAction(title: Localizable.notNow, style: .cancel, handler: cancelHandler))
    }
}

public final class AllowLANConnectionsAlert: SystemAlert {
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
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.settingsChange)
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
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.logout)
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
            message = Localizable.errorMitmDescription
        case .vpn:
            message = Localizable.errorMitmVpnDescription
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
        message = error.localizedDescription
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
    
    public init() { }
}

public final class ReconnectOnNetshieldChangeAlert: SystemAlert {
    public var title: String? = Localizable.reconnectionRequired
    public var message: String? = Localizable.netshieldAlertReconnectDescriptionOn
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(isOn: Bool, continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        message = isOn ? Localizable.netshieldAlertReconnectDescriptionOn : Localizable.netshieldAlertReconnectDescriptionOff
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

public final class SysexEnabledAlert: SystemAlert {
    public var title: String? = Localizable.sysexEnabledTitle
    public var message: String? = Localizable.sysexEnabledDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init() { }
}

public final class SysexInstallingErrorAlert: SystemAlert {
    public var title: String? = Localizable.sysexCannotEnable
    public var message: String? = Localizable.sysexErrorDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init() {
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
    
    public init(cancelHandler: @escaping() -> Void) {
        self.cancelHandler = cancelHandler
    }
}

public final class VPNAuthCertificateRefreshErrorAlert: SystemAlert {
    public var title: String? = Localizable.vpnauthCertfailTitle
    public var message: String? = Localizable.vpnauthCertfailDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
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
            message = Localizable.maximumDevicePlanLimitPart1(Localizable.tierPlus)
                + Localizable.maximumDevicePlanLimitPart2(CoreAppConstants.maxDeviceCount)
        } else {
            message = Localizable.maximumDeviceReachedDescription
        }
        
        actions.append(AlertAction(title: Localizable.upgrade, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: Localizable.noThanks, style: .cancel, handler: nil))
    }
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
            message = Localizable.subscriptionExpiredReconnectionDescription
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
            message = Localizable.delinquentReconnectionDescription
        }
    }
}

public final class VpnServerErrorAlert: SystemAlert {
    public var title: String? = Localizable.localAgentServerErrorTitle
    public var message: String? = Localizable.localAgentServerErrorMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public final class VpnServerSubscriptionErrorAlert: SystemAlert {
    public var title: String? = Localizable.localAgentPolicyViolationErrorTitle
    public var message: String? = Localizable.localAgentPolicyViolationErrorMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public final class AnnouncementOfferAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public let data: OfferPanel
    public let offerReference: String?

    public init(data: OfferPanel, offerReference: String?) {
        self.data = data
        self.offerReference = offerReference
    }
}

public final class DiscourageSecureCoreAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var onDontShowAgain: ((Bool) -> Void)?
    public var onActivate: (() -> Void)?
    public var onLearnMore: (() -> Void) = {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.learnMore)
    }
    public var dismiss: (() -> Void)?

    public init() { }
}

public final class WelcomeScreenAlert: UpsellAlert {
    /// This enum is used to narrow down the possible types of this alert. Theoretically we could just allow to use the `ModalType`
    /// but we don't want to use this alert (for now) for anything else than welcome alerts.
    public enum Plan {
        case plus(numberOfServers: Int, numberOfDevices: Int, numberOfCountries: Int)
        case unlimited
        case fallback
    }
    public let plan: Plan

    public init(plan: Plan) {
        self.plan = plan
    }

    public override var modalSource: UpsellModalSource? {
        return nil
    }
}

public extension WelcomeScreenAlert.Plan {
    init?(info: VpnDowngradeInfo) {
        // Replace hardcoded string with a proper solution VPNAPPL-2142
        if info.to.planName == "bundle2022" {
            self = .unlimited
        } else if info.to.maxTier.isPaidTier {
            @Dependency(\.serverRepository) var repository
            self = .plus(numberOfServers: repository.roundedServerCount,
                         numberOfDevices: CoreAppConstants.maxDeviceCount,
                         numberOfCountries: repository.countryCount())
        } else if info.to.maxTier > info.from.maxTier {
            self = .fallback
        } else {
            return nil
        }
    }
}

public final class ProfilesUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource { .profiles }
}

public final class VPNAcceleratorUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .vpnAccelerator }
}

public final class CustomizationUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .allowLan }
}

public final class CountryUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .countries }

    public let countryFlag: Image

    public init(countryFlag: Image) {
        self.countryFlag = countryFlag
    }
}

public final class NetShieldUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .netShield }
}

public final class SecureCoreUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .secureCore }
}

public final class SafeModeUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .safeMode }
}

public final class ModerateNATUpsellAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .moderateNat }
}

public final class SubuserWithoutConnectionsAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public let role: UserRole

    public init(role: UserRole) {
        self.role = role
    }
}

public final class TooManyCertificateRequestsAlert: SystemAlert {
    public var title: String? = Localizable.vpnauthTooManyCertsTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(retryAfter: TimeInterval? = nil) {
        guard let retryAfter = retryAfter else {
            message = Localizable.vpnauthTooManyCertsDescription
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

        message = Localizable.vpnauthTooManyCertsRetryAfter(minutesToWait)
    }
}

public final class NEKSOnT2Alert: SystemAlert {
    public static let t2kbUrlString = "https://protonvpn.com/support/macos-t2-chip-kill-switch/"

    public var title: String? = Localizable.neksT2Title
    public var message: String? = Localizable.neksT2Description
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?

    public let link = Localizable.neksT2Hyperlink
    public let killSwitchOffAction: AlertAction
    public let connectAnywayAction: AlertAction

    public init(killSwitchOffHandler: @escaping () -> Void, connectAnywayHandler: @escaping () -> Void) {
        self.killSwitchOffAction = AlertAction(title: Localizable.wgksKsOff, style: .confirmative, handler: killSwitchOffHandler)
        self.connectAnywayAction = AlertAction(title: Localizable.neksT2Connect, style: .destructive, handler: connectAnywayHandler)
    }
}

public final class ProtonUnreachableAlert: SystemAlert {
    public var title: String?
    public var message: String? = Localizable.protonWebsiteUnreachable
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {
    }
}

public final class LocalAgentSystemErrorAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    init(error: LocalAgentErrorSystemError) {
        switch error {
        case .splitTcp:
            title = Localizable.vpnAcceleratorTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.vpnAcceleratorTitle)
        case .netshield:
            title = Localizable.netshieldTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.netshieldTitle)
        case .nonRandomizedNat:
            title = Localizable.moderateNatTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.moderateNatTitle)
        case .safeMode:
            title = Localizable.nonStandardPortsTitle
            message = Localizable.vpnFeatureCannotBeSetError(Localizable.nonStandardPortsTitle)
        }
    }
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
            .init(title: Localizable.continue, style: .destructive, handler: connectAnywayHandler)
        ])
    }
}

public final class ConnectionCooldownAlert: UpsellAlert {
    public override var modalSource: UpsellModalSource? { .changeServer }

    public let until: Date
    public let duration: TimeInterval
    public let longSkip: Bool

    init(
        until: Date,
        duration: TimeInterval,
        longSkip: Bool,
        reconnectClosure: @escaping (() -> Void)
    ) {
        self.until = until
        self.duration = duration
        self.longSkip = longSkip

        super.init()
        actions = [.init(
            title: "Reconnect",
            style: .confirmative,
            handler: reconnectClosure
        )]
    }

    override public func continueAction() {
        actions.first(where: { $0.style == .confirmative })?
            .handler?()
    }
}

public final class UpgradeOperatingSystemAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions: [AlertAction]
    public var isError = false
    public var dismiss: (() -> Void)?

    init(minimumOSVersionRequired version: OperatingSystemVersion) {
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
            .init(title: Localizable.gotIt, style: .confirmative, handler: nil)
        ]
    }
}
