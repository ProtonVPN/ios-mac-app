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
    var title: String? { get }
    var message: String? { get }
    var joinedTitleAndMessage: Bool { get }
    var actions: [AlertAction] { get set }
    var isError: Bool { get }
    var dismiss: (() -> Void)? { get set }
    var activatingApp: Bool { get }
    var displayOnActiveScreen: Bool { get }
    var canDismissAutomaticallyOnConnection: Bool { get }
}

public extension SystemAlert {
    var joinedTitleAndMessage: Bool {
        false
    }

    var activatingApp: Bool {
        false
    }

    var displayOnActiveScreen: Bool {
        false
    }

    var canDismissAutomaticallyOnConnection: Bool {
        false
    }
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

    public static func noPlansAvailable(accountDashboardURL url: URL?, onDismiss: @escaping () -> Void) -> Self {
        let alert = Self(
            message: Localizable.upgradeUnavailableBody,
            accountDashboardURL: url
        )

        alert.actions = [
            AlertAction(title: Localizable.account, style: .confirmative) {
                @Dependency(\.linkOpener) var linkOpener
                linkOpener.open(url ?? VPNLink.accountDashboard.url)
                onDismiss()
            },
            AlertAction(title: Localizable.cancel, style: .cancel, handler: onDismiss),
        ]
        return alert
    }
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

public final class ProtonUnreachableAlert: SystemAlert {
    public var title: String?
    public var message: String? = Localizable.protonWebsiteUnreachable
    public var actions = [AlertAction]()
    public let isError: Bool = true
    public var dismiss: (() -> Void)?

    public init() {}
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

public final class PaymentRestorationAlert: SystemAlert {
    public enum Variant {
        case purchaseRestored(name: String)
        case transactionRecovered
        case error(Error)
    }

    private let variant: Variant

    public var actions: [AlertAction] = [.init(title: Localizable.ok, style: .confirmative, handler: nil)]
    public var dismiss: (() -> Void)?

    public init(_ variant: Variant) {
        self.variant = variant
    }

    public var isError: Bool {
        guard case .error = variant else { return false }
        return true
    }

    public var title: String? {
        switch variant {
        case .purchaseRestored, .transactionRecovered:
            Localizable.success
        case .error:
            Localizable.notFound
        }
    }

    public var message: String? {
        switch variant {
        case let .purchaseRestored(name):
            Localizable.purchaseRestored(name)
        case .transactionRecovered:
            Localizable.transactionRecovered
        case let .error(error):
            if let protonError = error as? ProtonVPNError {
                protonError.includeCode(inside: Localizable.paymentRestorationError)
            } else {
                Localizable.paymentRestorationError
            }
        }
    }
}

#if canImport(SystemExtensions)
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
                sysexError.code.includeCode(inside: Localizable.sysexErrorDescriptionSubcaseDefault)
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
