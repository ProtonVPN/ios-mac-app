//
//  AlertService.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public enum PrimaryActionType {
    case confirmative
    case destructive
    case cancel
}

public protocol CoreAlertServiceFactory {
    func makeCoreAlertService() -> CoreAlertService
}

public protocol CoreAlertService: class {
    func push(alert: SystemAlert)
}

public protocol UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService
}

public protocol UIAlertService: class {
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

public protocol SystemAlert: AnyObject {
    var title: String? { get set }
    var message: String? { get set }
    var actions: [AlertAction] { get set }
    var isError: Bool { get }
    var dismiss: (() -> Void)? { get set }
}

public protocol UserAccountUpdateAlert: SystemAlert {
    var imageName: String? { get }
    var reconnectionInfo: VpnReconnectInfo? { get }
    var displayFeatures: Bool { get }
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

/// App should update to be able to use API
public class AppUpdateRequiredAlert: SystemAlert {
    public var title: String? = LocalizedString.updateRequired
    public var message: String? = LocalizedString.updateRequiredNoLongerSupported
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(_ apiError: ApiError) {
        message = apiError.localizedDescription
    }
}

public class CannotAccessVpnCredentialsAlert: SystemAlert {
    public var title: String? = LocalizedString.failedToAccessVpnCredentialsTitle
    public var message: String? = LocalizedString.failedToAccessVpnCredentialsDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: confirmHandler))
    }
}

public class ExistingConnectionAlert: SystemAlert {
    public var title: String? = LocalizedString.existingSession
    public var message: String? = LocalizedString.existingSessionToServer
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
}

public class FirstTimeConnectingAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public class P2pBlockedAlert: SystemAlert {
    public var title: String? = LocalizedString.p2pDetectedPopupTitle
    public var message: String? = LocalizedString.p2pDetectedPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public class P2pForwardedAlert: SystemAlert {
    public var title: String? = LocalizedString.p2pForwardedPopupTitle
    public var message: String? = LocalizedString.p2pForwardedPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public class RefreshTokenExpiredAlert: SystemAlert {
    public var title: String? = LocalizedString.invalidRefreshToken
    public var message: String? = LocalizedString.invalidRefreshTokenPleaseLogin
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
}

public class UpgradeRequiredAlert: SystemAlert {
    public let tier: Int
    public let serverType: ServerType
    public let forSpecificCountry: Bool
    
    public init(tier: Int, serverType: ServerType, forSpecificCountry: Bool, confirmHandler: (() -> Void)?) {
        self.tier = tier
        self.serverType = serverType
        self.forSpecificCountry = forSpecificCountry
        self.title = tier == CoreAppConstants.VpnTiers.basic
        ? LocalizedString.paidRequired : LocalizedString.plusRequired
        self.actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: { confirmHandler?() }))
    }
    
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
}

public class UpgradeUnavailableAlert: SystemAlert {
    public var title: String? = LocalizedString.upgradeUnavailableTitle
    public var message: String? = LocalizedString.upgradeUnavailableBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {
        let confirmHandler: () -> Void = {
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.accountDashboard)
        }
        actions.append(AlertAction(title: LocalizedString.account, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class DelinquentUserAlert: SystemAlert {
    public var title: String? = LocalizedString.delinquentUserTitle
    public var message: String? = LocalizedString.delinquentUserDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() { }
}

public class VpnStuckAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnStuckDisconnectingTitle
    public var message: String? = LocalizedString.vpnStuckDisconnectingBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {}
}

public class VpnNetworkUnreachableAlert: SystemAlert {
    public var title: String? = LocalizedString.notConnectedToTheInternet
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
}

public class SessionCountLimitAlert: SystemAlert {
    public var title: String? = LocalizedString.sessionCountReachedTitle
    public var message: String? = LocalizedString.sessionCountReachedDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
}

public class StoreKitErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.errorOccured
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(withMessage: String?) {
        self.message = withMessage
    }
}

public class StoreKitUserValidationByPassAlert: SystemAlert {
    public var title: String? = LocalizedString.warning
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(withMessage: String?, confirmHandler: @escaping () -> Void) {
        self.message = withMessage
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class MaintenanceAlert: SystemAlert {
    public var title: String? = LocalizedString.allServersInProfileUnderMaintenance
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    public let type: MaintenanceAlertType
    
    public init() {
        title = LocalizedString.allServersInProfileUnderMaintenance
        type = .alert
    }
    
    public init(countryName: String) {
        title = LocalizedString.countryServersUnderMaintenance(countryName)
        type = .alert
    }
    
    /// If `forSpecificCountry` is set, switches between country and servers texts, if it's nil, uses one text
    public init(forSpecificCountry: Bool?) {
        if let forSpecificCountry = forSpecificCountry {
            title = forSpecificCountry ? LocalizedString.allServersInCountryUnderMaintenance : LocalizedString.allServersUnderMaintenance
        } else {
            title = LocalizedString.serverUnderMaintenance
        }
        type = .notification
    }
    
    public enum MaintenanceAlertType {
        case alert
        case notification
    }
}

public class SecureCoreToggleDisconnectAlert: SystemAlert {
    public var title: String? = LocalizedString.warning
    public var message: String? = LocalizedString.viewToggleWillCauseDisconnect
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }    
}

public class ChangeProtocolDisconnectAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnConnectionActive
    public var message: String? = LocalizedString.changeProtocolDisconnectWarning
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class ReconnectOnSettingsChangeAlert: SystemAlert {
    public var title: String? = LocalizedString.changeSettings
    public var message: String? = LocalizedString.reconnectOnSettingsChangeBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class ReconnectOnActionAlert: SystemAlert {
    public var title: String?
    public var message: String? = LocalizedString.actionRequiresReconnect
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(actionTitle: String, confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        title = actionTitle
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class TurnOnKillSwitchAlert: SystemAlert {
    public var title: String? = LocalizedString.turnKsOnTitle
    public var message: String? = LocalizedString.turnKsOnDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.notNow, style: .cancel, handler: cancelHandler))
    }
}

public class AllowLANConnectionsAlert: SystemAlert {
    public var title: String? = LocalizedString.allowLanTitle
    public var message: String? = LocalizedString.allowLanDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(connected: Bool, confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        if connected {
            message! += "\n\n" + LocalizedString.allowLanNote
        }
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.notNow, style: .cancel, handler: cancelHandler))
    }
}

public class ReconnectOnSmartProtocolChangeAlert: SystemAlert {
    public var title: String? = LocalizedString.smartProtocolReconnectModalTitle
    public var message: String? = LocalizedString.smartProtocolReconnectModalBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class LogoutWarningAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnConnectionActive
    public var message: String? = LocalizedString.logOutWarning
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class LogoutWarningLongAlert: LogoutWarningAlert {
    override public init(confirmHandler: @escaping () -> Void) {
        super.init(confirmHandler: confirmHandler)
        message = LocalizedString.logOutWarningLong
    }
}

public class BugReportSentAlert: SystemAlert {
    public var title: String? = ""
    public var message: String? = LocalizedString.reportSuccess
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: confirmHandler))
    }
}

public class PlanPurchaseErrorAlert: SystemAlert {
    public var title: String?
    public var message: String? = ""
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public let error: Error
    public var dismiss: (() -> Void)?
    
    public init(error: Error, planDescription: String) {
        self.error = error
                
        if error is StoreKitManagerImplementation.Errors {
            title = LocalizedString.errorOccured
            message = error.localizedDescription
        } else {
            message = String(format: error.localizedDescription, planDescription)
        }
    }
}

public class UnknownErrortAlert: SystemAlert {
    public var title: String? = LocalizedString.errorUnknownTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(error: Error, confirmHandler: (() -> Void)?) {
        message = error.localizedDescription
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: confirmHandler))
    }
}

public class ErrorNotificationAlert: SystemAlert {
    public var title: String? = LocalizedString.errorUnknownTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    public var accessibilityIdentifier: String?
    
    public init(error: Error) {
        message = error.localizedDescription
        let nsError = error as NSError
        accessibilityIdentifier = "Error notification with code \(nsError.code)"
    }
}

public class SuccessNotificationAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(message: String) {
        self.message = message
    }
}

public class UserVerificationAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public let verificationMethods: VerificationMethods
    public let success: ((HumanVerificationToken) -> Void)
    public let failure: ((Error) -> Void)
    public let error: Error
    
    public init(verificationMethods: VerificationMethods, error: Error, success: @escaping ((HumanVerificationToken) -> Void), failure: @escaping ((Error) -> Void)) {
        self.verificationMethods = verificationMethods
        self.success = success
        self.failure = failure
        self.error = error
        #if os(macOS)
        self.message = error.localizedDescription
        #endif
    }
}

public class ApplyCreditAfterRegistrationFailedAlert: SystemAlert {
    public var title: String? = LocalizedString.errorApplyPaymentFailedOnRegistrationTitle
    public var message: String? = LocalizedString.errorApplyPaymentFailedOnRegistrationMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(type: MessageType, retryHandler: @escaping () -> Void, supportHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.retry, style: .confirmative, handler: retryHandler))
        actions.append(AlertAction(title: LocalizedString.errorApplyPaymentFailedOnRegistrationSupport, style: .confirmative, handler: supportHandler))
        
        switch type {
        case .registration:
            title = LocalizedString.errorApplyPaymentFailedOnRegistrationTitle
            message = LocalizedString.errorApplyPaymentFailedOnRegistrationMessage
        case .upgrade:
            title = LocalizedString.errorApplyPaymentFailedOnUpgradeTitle
            message = LocalizedString.errorApplyPaymentFailedOnUpgradeMessage
        }
    }
    
    public enum MessageType {
        case registration
        case upgrade
    }
}

public class ReportBugAlert: SystemAlert {
    public var title: String? = LocalizedString.errorUnknownTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {}
}

public class MITMAlert: SystemAlert {
    public enum MessageType {
        case api
        case vpn
    }
    
    public var title: String? = LocalizedString.errorMitmTitle
    public var message: String? = LocalizedString.errorMitmDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(messageType: MessageType = .api) {
        switch messageType {
        case .api:
            message = LocalizedString.errorMitmDescription
        case .vpn:
            message = LocalizedString.errorMitmVpnDescription
        }        
    }
}

public class InvalidHumanVerificationCodeAlert: SystemAlert {
    public var title: String? = LocalizedString.errorInvalidHumanVerificationCodeTitle
    public var message: String? = LocalizedString.errorInvalidHumanVerificationCodeMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(tryAnother: @escaping () -> Void, resend: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.errorInvalidHumanVerificationCodeTryOther, style: .cancel, handler: tryAnother))
        actions.append(AlertAction(title: LocalizedString.errorInvalidHumanVerificationCodeResend, style: .confirmative, handler: resend))
    }    
}

public class UnreachableNetworkAlert: SystemAlert {
    public var title: String? = LocalizedString.warning
    public var message: String? = LocalizedString.neUnableToConnectToHost
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(error: Error, troubleshoot: @escaping () -> Void) {
        message = error.localizedDescription
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
        actions.append(AlertAction(title: LocalizedString.neTroubleshoot, style: .confirmative, handler: troubleshoot))
    }
}

public class ConnectionTroubleshootingAlert: SystemAlert {
    public var title: String? = LocalizedString.errorUnknownTitle
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {}
}

public class RegistrationUserAlreadyExistsAlert: SystemAlert {
    public var title: String? = LocalizedString.warning
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(error: Error, forgotCallback: @escaping () -> Void, resetCallback: @escaping () -> Void ) {
        message = error.localizedDescription
        actions.append(AlertAction(title: LocalizedString.forgotUsername, style: .confirmative, handler: forgotCallback))
        actions.append(AlertAction(title: LocalizedString.resetPassword, style: .confirmative, handler: resetCallback))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class PaymentFailedAlert: SystemAlert {
    public var title: String? = LocalizedString.errorApplyPaymentFailedTitle
    public var message: String? = LocalizedString.errorApplyPaymentFailedMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(retryHandler: @escaping () -> Void, freeHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.errorApplyPaymentFailedRetry, style: .confirmative, handler: retryHandler))
        actions.append(AlertAction(title: LocalizedString.errorApplyPaymentFailedFree, style: .cancel, handler: freeHandler))
    }
}

public class VpnServerOnMaintenanceAlert: SystemAlert {
    public var title: String? = LocalizedString.maintenanceOnServerDetectedTitle
    public var message: String? = LocalizedString.maintenanceOnServerDetectedDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() { }
}

public class ReconnectOnNetshieldChangeAlert: SystemAlert {
    public var title: String? = LocalizedString.reconnectionRequired
    public var message: String? = LocalizedString.netshieldAlertReconnectDescriptionOn
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(isOn: Bool, continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        message = isOn ? LocalizedString.netshieldAlertReconnectDescriptionOn : LocalizedString.netshieldAlertReconnectDescriptionOff
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class NetShieldRequiresUpgradeAlert: SystemAlert {
    public var title: String? = LocalizedString.upgradeRequired
    public var message: String? = LocalizedString.netshieldAlertUpgradeDescription + "\n\n" + LocalizedString.getPlusForFeature
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: LocalizedString.upgrade, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class SecureCoreRequiresUpgradeAlert: SystemAlert {
    public var title: String? = LocalizedString.upgradeRequired
    public var message: String? = LocalizedString.upgradeRequiredSecurecoreDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(continueHandler: @escaping () -> Void, cancelHandler: (() -> Void)? = nil) {
        actions.append(AlertAction(title: LocalizedString.upgrade, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: LocalizedString.maybeLater, style: .cancel, handler: cancelHandler))
    }
}

public class SysexInstallationRequiredAlert: SystemAlert {
    public var title: String? = LocalizedString.sysexSettingsTitle
    public var message: String? = LocalizedString.sysexSettingsDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(continueHandler: @escaping () -> Void, cancel: (() -> Void)? = nil, dismiss: (() -> Void)? = nil ) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: continueHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancel))
    }
}

public class SysexEnabledAlert: SystemAlert {
    public var title: String? = LocalizedString.sysexEnabledTitle
    public var message: String? = LocalizedString.sysexEnabledDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init() {
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: nil))
    }
}

public class SysexInstallingErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.sysexCannotEnable
    public var message: String? = LocalizedString.sysexErrorDescription
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init() {
        actions.append(AlertAction(title: LocalizedString.ok, style: .cancel, handler: nil))
    }
}

public class SystemExtensionTourAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    public var continueHandler: () -> Void
    public typealias CloseConditionCallback = (@escaping (Bool) -> Void) -> Void
    public var isTimeToClose: CloseConditionCallback
    public var extensionsCount: Int
    
    public init(extensionsCount: Int, isTimeToClose: @escaping CloseConditionCallback, continueHandler: @escaping () -> Void) {
        self.extensionsCount = extensionsCount
        self.isTimeToClose = isTimeToClose
        self.continueHandler = continueHandler
    }
}

public class VPNAuthCertificateRefreshErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnauthCertfailTitle
    public var message: String? = LocalizedString.vpnauthCertfailDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public class MaxSessionsAlert: UserAccountUpdateAlert {
    public var imageName: String? = "sessions_limit"
    public var displayFeatures: Bool = false
    public var reconnectionInfo: VpnReconnectInfo?
    public var title: String? = LocalizedString.maximumDeviceTitle
    public var message: String?
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(userCurrentCredentials: VpnCredentials) {
        switch userCurrentCredentials.accountPlan {
        case .free, .basic:
            message = LocalizedString.maximumDeviceDescription(AccountPlan.plus.name, AccountPlan.plus.devicesCount)
        default:
            message = LocalizedString.maximumDeviceReachedDescription
        }
        
        actions.append(AlertAction(title: LocalizedString.upgradeAgain, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: LocalizedString.noThanks, style: .cancel, handler: nil))
    }
}

public class UserPlanDowngradedAlert: UserAccountUpdateAlert {
    public var imageName: String?
    public var displayFeatures: Bool = true
    public var reconnectionInfo: VpnReconnectInfo?
    public var title: String? = LocalizedString.subscriptionExpiredTitle
    public var message: String? = LocalizedString.subscriptionExpiredDescription
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(accountUpdate: VpnDowngradeInfo, reconnectionInfo: VpnReconnectInfo?) {
        actions.append(AlertAction(title: LocalizedString.upgradeAgain, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: LocalizedString.noThanks, style: .cancel, handler: nil))
        self.reconnectionInfo = reconnectionInfo
        if reconnectionInfo?.to != nil {
            message = LocalizedString.subscriptionExpiredReconnectionDescription
        }
    }
}

public class UserBecameDelinquentAlert: UserAccountUpdateAlert {
    public var imageName: String?
    public var displayFeatures: Bool = false
    public var reconnectionInfo: VpnReconnectInfo?
    public var title: String? = LocalizedString.delinquentTitle
    public var message: String? = LocalizedString.delinquentDescription
    public var actions: [AlertAction] = []
    public var isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(reconnectionInfo: VpnReconnectInfo?) {
        actions.append(AlertAction(title: LocalizedString.updateBilling, style: .confirmative, handler: nil))
        actions.append(AlertAction(title: LocalizedString.noThanks, style: .cancel, handler: nil))
        self.reconnectionInfo = reconnectionInfo
        if reconnectionInfo?.to != nil {
            message = LocalizedString.delinquentReconnectionDescription
        }
    }
}

public class VpnServerErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.localAgentServerErrorTitle
    public var message: String? = LocalizedString.localAgentServerErrorMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public class VpnServerSubscriptionErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.localAgentPolicyViolationErrorTitle
    public var message: String? = LocalizedString.localAgentPolicyViolationErrorMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public class WireguardProfileErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.wireguard
    public var message: String? = LocalizedString.wireguardProfileWarningText
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() { }
}

public class AnnouncmentOfferAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    public let data: OfferPanel

    public init(data: OfferPanel) {
        self.data = data
    }
}

public class SubuserWithoutConnectionsAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {
    }
}

public class TooManyCertificateRequestsAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnauthTooManyCertsTitle
    public var message: String? = LocalizedString.vpnauthTooManyCertsDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
}

public class WireguardKSOnCatalinaAlert: SystemAlert {
    public var title: String? = LocalizedString.wgksTitle
    public var message: String? = LocalizedString.wgksDescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(killswiftOffHandler: @escaping () -> Void, openVpnHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.wgksKsOff, style: .confirmative, handler: killswiftOffHandler))
        actions.append(AlertAction(title: LocalizedString.wgksOvpn, style: .confirmative, handler: openVpnHandler))
    }
}
