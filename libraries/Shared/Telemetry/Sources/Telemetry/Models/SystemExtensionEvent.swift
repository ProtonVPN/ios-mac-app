//
//  Created on 29/09/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Domain
import Foundation

public struct SystemExtensionEvent: TelemetryEvent, Encodable, Equatable {
    public let measurementGroup: String = "vpn.any.system_extension"
    public let event: Event
    public let dimensions: Dimensions
    public let values: Values

    /// The name of the event.
    public enum Event: String, Encodable, Sendable {
        case installAttempt = "sysext_install_attempt"
        case approvalPromptDisplay = "sysext_approval_prompt_display"
        case approvalPromptAction = "sysext_approval_prompt_action"
        case installResult = "sysext_install_result"
        case relocationPromptDisplay = "relocation_prompt_display"
        case relocationPromptAction = "relocation_prompt_action"
    }

    /// The dimensions of the event. Nil ones are left out of the payload.
    public struct Dimensions: Encodable, Equatable {
        enum CodingKeys: String, CodingKey {
            case entryPoint = "entry_point"
            case extensionType = "extension_type"
            case isUserInitiated = "is_user_initiated"
            case promptOutcome = "prompt_outcome"
            case outcome
            case errorCode = "error_code"
            case isTargetExtensionActive = "is_target_extension_active"
            case vpnProtocol = "protocol"
            case isSmartProtocol = "is_smart_protocol"
            case installLocation = "install_location"
            case promptAction = "prompt_action"
            case userTier = "user_tier"
        }

        var entryPoint: EntryPoint?
        var extensionType: ExtensionType?
        var isUserInitiated: Flag?
        var promptOutcome: PromptOutcome?
        var outcome: Outcome?
        var errorCode: ErrorCode?
        var isTargetExtensionActive: IsTargetExtensionActive?
        var vpnProtocol: ProtocolName?
        var isSmartProtocol: Flag?
        var installLocation: InstallLocation?
        var promptAction: PromptAction?
        var userTier: CommonTelemetryDimensions.UserTier?
    }

    /// The values of the event.
    public struct Values: Encodable, Equatable {
        enum CodingKeys: String, CodingKey {
            case timeToResult = "time_to_result"
        }

        /// Milliseconds between the activation request and its outcome.
        var timeToResult: Int?
    }

    /// Which call site requested the activation.
    public enum EntryPoint: String, Encodable, Sendable {
        case appLaunch = "app_launch"
        case login
        case connectionSettings = "connection_settings"
        case profileCreate = "profile_create"
        case profileConnect = "profile_connect"
        case protocolChange = "protocol_change"
        case splitTunnelSetting = "split_tunnel_setting"
    }

    /// Which system extension an event refers to.
    public enum ExtensionType: String, Encodable, Sendable {
        case wireGuard = "wireguard"
        case splitTunnel = "split_tunnel"
    }

    public enum Flag: String, Encodable, Sendable {
        case `true`
        case `false`

        init(_ value: Bool) {
            self = value ? .true : .false
        }
    }

    /// What the user did with the approval tour. `skipped` means the app needed approval but did not show the tour.
    public enum PromptOutcome: String, Encodable, Sendable {
        case proceeded
        case skipped
        case cancelled
    }

    /// How an activation request ended, as sent.
    public enum Outcome: String, Encodable, Sendable {
        case installed
        case upgraded
        case alreadyThere = "already_there"
        case failed
        case userDeclined = "user_declined"
    }

    /// The `charCode` of the `OSSystemExtensionError`.
    public enum ErrorCode: String, Encodable, Sendable {
        case authorizationRequired = "SXAR"
        case codeSignatureInvalid = "SXCS"
        case duplicateExtensionIdentifier = "SXDI"
        case extensionMissingIdentifier = "SXMI"
        case extensionNotFound = "SXNF"
        case forbiddenBySystemPolicy = "SXSP"
        case missingEntitlement = "SXME"
        case requestCanceled = "SXRC"
        case requestSuperseded = "SXRS"
        case unknownExtensionCategory = "SXEC"
        case unsupportedParentBundleLocation = "SXBL"
        case validationFailed = "SXVF"
        case unknown = "SXUK"
        /// A code added after this app was built.
        case unknownDefault = "SXDF"
        case na = "n/a"
    }

    /// Where the app bundle runs from. The path itself is never sent.
    public enum InstallLocation: String, Encodable, Sendable {
        case applications
        case downloads
        case dmgVolume = "dmg_volume"
        case translocated
        case other
    }

    /// Whether an extension that was already on the system is enabled. `n/a` for other outcomes.
    public enum IsTargetExtensionActive: String, Encodable, Sendable {
        case `true`
        case `false`
        case na = "n/a"
    }

    /// The protocol setting when the activation was requested, named as in `vpn.any.connection`. Smart Protocol has
    /// not picked a protocol yet at that point, so its events leave this out and set `is_smart_protocol`.
    public enum ProtocolName: String, Encodable, Sendable {
        case ikev2
        case wireGuardUDP = "wireguard_udp"
        case wireGuardTCP = "wireguard_tcp"
        case wireGuardTLS = "wireguard_tls"
    }

    /// What the user did with the install location recovery prompt.
    public enum PromptAction: String, Encodable, Sendable {
        case openedFinder = "opened_finder"
        case dismissed
        case resolved
    }
}

// MARK: - Reports

public extension SystemExtensionEvent {
    /// What a feature reports about a system extension. The reporter adds the user tier and the install location.
    enum Report: Equatable, Sendable {
        /// An activation request was submitted.
        case installAttempt(origin: Origin, extensionType: ExtensionType)
        /// The approval tour was shown for an extension waiting for the user's approval.
        case approvalPromptDisplay(origin: Origin, extensionType: ExtensionType)
        /// The user answered the approval tour, or the app needed approval without showing it.
        case approvalPromptAction(origin: Origin, extensionType: ExtensionType, outcome: PromptOutcome)
        /// An activation request ended.
        case installResult(
            origin: Origin,
            extensionType: ExtensionType,
            outcome: InstallOutcome,
            connectionProtocol: ConnectionProtocol,
            timeToResult: TimeInterval
        )
        /// The install location recovery prompt was shown.
        case relocationPromptDisplay(entryPoint: EntryPoint)
        /// The user answered the install location recovery prompt.
        case relocationPromptAction(PromptAction)
    }

    /// Who asked for an activation, and whether the user did it rather than the app.
    struct Origin: Equatable, Sendable {
        public let entryPoint: EntryPoint
        public let isUserInitiated: Bool

        public init(entryPoint: EntryPoint, isUserInitiated: Bool) {
            self.entryPoint = entryPoint
            self.isUserInitiated = isUserInitiated
        }
    }

    /// How an activation request ended.
    enum InstallOutcome: Equatable, Sendable {
        /// The extension was not on the system before.
        case installed
        /// An older version of the extension was replaced.
        case upgraded
        /// The extension was already on the system. `isExtensionActive` is nil when the system did not say.
        case alreadyThere(isExtensionActive: Bool?)
        case failed(ErrorCode)
        /// The user closed the approval tour without opening System Settings.
        case userDeclined

        var outcome: Outcome {
            switch self {
            case .installed: .installed
            case .upgraded: .upgraded
            case .alreadyThere: .alreadyThere
            case .failed: .failed
            case .userDeclined: .userDeclined
            }
        }

        var errorCode: ErrorCode {
            guard case let .failed(errorCode) = self else {
                return .na
            }
            return errorCode
        }

        var isTargetExtensionActive: IsTargetExtensionActive {
            guard case let .alreadyThere(isExtensionActive) = self, let isExtensionActive else {
                return .na
            }
            return isExtensionActive ? .true : .false
        }

        /// Whether the extension is on the system after the request.
        var extensionIsInstalled: Bool {
            switch self {
            case .installed, .upgraded, .alreadyThere: true
            case .failed, .userDeclined: false
            }
        }
    }
}

// MARK: - Events

extension SystemExtensionEvent {
    /// What the reporter adds to every event.
    struct Context: Equatable {
        let installLocation: InstallLocation
        let userTier: CommonTelemetryDimensions.UserTier
    }

    init(_ report: Report, context: Context) {
        switch report {
        case let .installAttempt(origin, extensionType):
            let dimensions = Dimensions(origin: origin, extensionType: extensionType, context: context)
            self.init(event: .installAttempt, dimensions: dimensions, values: Values())

        case let .approvalPromptDisplay(origin, extensionType):
            let dimensions = Dimensions(origin: origin, extensionType: extensionType, context: context)
            self.init(event: .approvalPromptDisplay, dimensions: dimensions, values: Values())

        case let .approvalPromptAction(origin, extensionType, outcome):
            var dimensions = Dimensions(origin: origin, extensionType: extensionType, context: context)
            dimensions.promptOutcome = outcome
            self.init(event: .approvalPromptAction, dimensions: dimensions, values: Values())

        case let .installResult(origin, extensionType, outcome, connectionProtocol, timeToResult):
            var dimensions = Dimensions(origin: origin, extensionType: extensionType, context: context)
            dimensions.outcome = outcome.outcome
            dimensions.errorCode = outcome.errorCode
            dimensions.isTargetExtensionActive = outcome.isTargetExtensionActive
            dimensions.vpnProtocol = ProtocolName(connectionProtocol)
            dimensions.isSmartProtocol = Flag(connectionProtocol == .smartProtocol)
            let values = Values(timeToResult: Int((timeToResult * 1000).rounded()))
            self.init(event: .installResult, dimensions: dimensions, values: values)

        case let .relocationPromptDisplay(entryPoint):
            let dimensions = Dimensions(
                entryPoint: entryPoint,
                installLocation: context.installLocation,
                userTier: context.userTier
            )
            self.init(event: .relocationPromptDisplay, dimensions: dimensions, values: Values())

        case let .relocationPromptAction(promptAction):
            let dimensions = Dimensions(
                installLocation: context.installLocation,
                promptAction: promptAction,
                userTier: context.userTier
            )
            self.init(event: .relocationPromptAction, dimensions: dimensions, values: Values())
        }
    }
}

extension SystemExtensionEvent.Dimensions {
    /// The dimensions every event about an activation request shares.
    init(
        origin: SystemExtensionEvent.Origin,
        extensionType: SystemExtensionEvent.ExtensionType,
        context: SystemExtensionEvent.Context
    ) {
        self.init(
            entryPoint: origin.entryPoint,
            extensionType: extensionType,
            isUserInitiated: .init(origin.isUserInitiated),
            installLocation: context.installLocation,
            userTier: context.userTier
        )
    }
}

// MARK: - Dimension values

extension SystemExtensionEvent.InstallLocation {
    init(_ location: BundleLocation) {
        switch location {
        case .applications:
            self = .applications
        case .downloads:
            self = .downloads
        case .dmgVolume:
            self = .dmgVolume
        case .translocated:
            self = .translocated
        case .other:
            self = .other
        }
    }
}

extension SystemExtensionEvent.ProtocolName {
    /// The name for a protocol setting, or nil for Smart Protocol.
    init?(_ connectionProtocol: ConnectionProtocol) {
        switch connectionProtocol {
        case .smartProtocol:
            return nil
        case .vpnProtocol(.ike):
            self = .ikev2
        case .vpnProtocol(.wireGuard(.udp)):
            self = .wireGuardUDP
        case .vpnProtocol(.wireGuard(.tcp)):
            self = .wireGuardTCP
        case .vpnProtocol(.wireGuard(.tls)):
            self = .wireGuardTLS
        }
    }
}
