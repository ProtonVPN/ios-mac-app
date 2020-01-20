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
    public var title: String? = LocalizedString.updateRequiredTitle
    public var message: String? = LocalizedString.updateRequiredDescription
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
    public var title: String? = LocalizedString.p2pDetectedPopUpTitle
    public var message: String? = LocalizedString.p2pDetectedPopUpBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public class P2pForwardedAlert: SystemAlert {
    public var title: String? = LocalizedString.p2pForwardedPopUpTitle
    public var message: String? = LocalizedString.p2pForwardedPopUpBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
}

public class RefreshTokenExpiredAlert: SystemAlert {
    public var title: String? = LocalizedString.invalidRefreshTokenTitle
    public var message: String? = LocalizedString.invalidRefreshTokenDescription
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

public class UpgradeUnavailbleAlert: SystemAlert {
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
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.account, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class VpnStuckAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnStuckDisconnectingTitle
    public var message: String? = LocalizedString.vpnStuckDisconnectingBody
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {}
}

public class NetworkUnreachableAlert: SystemAlert {
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
        title = String(format: LocalizedString.countryServersUnderMaintenance, countryName)
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

public class ConfirmVpnDisconnectAlert: SystemAlert {
    public var title: String? = LocalizedString.warning
    public var message: String? = LocalizedString.viewToggleWillCauseDisconnect
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .destructive, handler: confirmHandler))
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
        if let nsError = error as? NSError {
            accessibilityIdentifier = "Error notification with code \(nsError.code)"
        }
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
    
    public init(verificationMethods: VerificationMethods, message: String?, success: @escaping ((HumanVerificationToken) -> Void), failure: @escaping ((Error) -> Void)) {
        self.verificationMethods = verificationMethods
        self.success = success
        self.failure = failure
    }
}

public class ApplyCreditAfterRegistrationFailedAlert: SystemAlert {
    public var title: String? = LocalizedString.errorApplyPaymentOnRegistrationTitle
    public var message: String? = LocalizedString.errorApplyPaymentOnRegistrationMessage
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init(retryHandler: @escaping () -> Void, supportHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.retry, style: .confirmative, handler: retryHandler))
        actions.append(AlertAction(title: LocalizedString.errorApplyPaymentOnRegistrationSupport, style: .confirmative, handler: supportHandler))
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
    public var title: String? = LocalizedString.errorMITMTitle
    public var message: String? = LocalizedString.errorMITMdescription
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?
    
    public init() {}
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
