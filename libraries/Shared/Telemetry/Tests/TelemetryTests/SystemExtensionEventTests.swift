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

import Dependencies
import Domain
import Foundation
@testable import Telemetry
import Testing

@Suite("System extension telemetry")
struct SystemExtensionEventTests {
    private let origin = SystemExtensionEvent.Origin(entryPoint: .protocolChange, isUserInitiated: true)
    private let context = SystemExtensionEvent.Context(installLocation: .downloads, userTier: .paid)

    private func payload(
        _ event: SystemExtensionEvent
    ) throws -> (dimensions: [String: String], values: [String: Any]) {
        let dictionary = event.toJSONDictionary()
        let dimensions = try #require(dictionary["Dimensions"] as? [String: String])
        let values = try #require(dictionary["Values"] as? [String: Any])
        #expect(dictionary["MeasurementGroup"] as? String == "vpn.any.system_extension")
        return (dimensions, values)
    }

    // MARK: - Payload

    @Test("An install attempt sends only its five dimensions")
    func installAttemptPayload() throws {
        let launch = SystemExtensionEvent.Origin(entryPoint: .appLaunch, isUserInitiated: false)
        let event = SystemExtensionEvent(.installAttempt(origin: launch, extensionType: .splitTunnel), context: context)

        let (dimensions, values) = try payload(event)

        #expect(event.toJSONDictionary()["Event"] as? String == "sysext_install_attempt")
        #expect(dimensions == [
            "entry_point": "app_launch",
            "extension_type": "split_tunnel",
            "is_user_initiated": "false",
            "install_location": "downloads",
            "user_tier": "paid",
        ])
        #expect(values.isEmpty)
    }

    @Test("A shown approval tour sends the request's dimensions")
    func approvalPromptDisplayPayload() throws {
        let event = SystemExtensionEvent(
            .approvalPromptDisplay(origin: origin, extensionType: .wireGuard),
            context: .init(installLocation: .translocated, userTier: .nonUser)
        )

        let (dimensions, values) = try payload(event)

        #expect(event.toJSONDictionary()["Event"] as? String == "sysext_approval_prompt_display")
        #expect(dimensions == [
            "entry_point": "protocol_change",
            "extension_type": "wireguard",
            "is_user_initiated": "true",
            "install_location": "translocated",
            "user_tier": "non-user",
        ])
        #expect(values.isEmpty)
    }

    @Test("An answered approval tour also sends what the user did")
    func approvalPromptActionPayload() throws {
        let event = SystemExtensionEvent(
            .approvalPromptAction(origin: origin, extensionType: .splitTunnel, outcome: .skipped),
            context: context
        )

        let (dimensions, values) = try payload(event)

        #expect(event.toJSONDictionary()["Event"] as? String == "sysext_approval_prompt_action")
        #expect(dimensions == [
            "entry_point": "protocol_change",
            "extension_type": "split_tunnel",
            "is_user_initiated": "true",
            "prompt_outcome": "skipped",
            "install_location": "downloads",
            "user_tier": "paid",
        ])
        #expect(values.isEmpty)
    }

    @Test("A failed install result sends the error code, the protocol and the time in milliseconds")
    func failedInstallResultPayload() throws {
        let event = SystemExtensionEvent(
            .installResult(
                origin: origin,
                extensionType: .wireGuard,
                outcome: .failed(.unsupportedParentBundleLocation),
                connectionProtocol: .vpnProtocol(.wireGuard(.tls)),
                timeToResult: 1.23456
            ),
            context: context
        )

        let (dimensions, values) = try payload(event)

        #expect(dimensions == [
            "entry_point": "protocol_change",
            "extension_type": "wireguard",
            "is_user_initiated": "true",
            "outcome": "failed",
            "error_code": "SXBL",
            "is_target_extension_active": "n/a",
            "protocol": "wireguard_tls",
            "is_smart_protocol": "false",
            "install_location": "downloads",
            "user_tier": "paid",
        ])
        #expect(values["time_to_result"] as? Int == 1235)
    }

    @Test("Smart Protocol has not picked a protocol yet, so the result leaves it out and sets is_smart_protocol")
    func smartProtocolResultPayload() throws {
        let event = SystemExtensionEvent(
            installResult(.installed, connectionProtocol: .smartProtocol),
            context: context
        )

        let (dimensions, _) = try payload(event)

        #expect(dimensions["protocol"] == nil)
        #expect(dimensions["is_smart_protocol"] == "true")
    }

    @Test(
        "An extension that was already there reports whether it is enabled",
        arguments: [
            (Bool?.some(true), "true"),
            (Bool?.some(false), "false"),
            (Bool?.none, "n/a"),
        ]
    )
    func alreadyThereReportsTheExtensionState(isExtensionActive: Bool?, expected: String) throws {
        let event = SystemExtensionEvent(
            installResult(.alreadyThere(isExtensionActive: isExtensionActive)),
            context: context
        )

        let (dimensions, _) = try payload(event)

        #expect(dimensions["outcome"] == "already_there")
        #expect(dimensions["error_code"] == "n/a")
        #expect(dimensions["is_target_extension_active"] == expected)
    }

    @Test("The recovery prompt events send only their own dimensions")
    func relocationPromptPayloads() throws {
        let display = try payload(SystemExtensionEvent(
            .relocationPromptDisplay(entryPoint: .profileCreate),
            context: .init(installLocation: .dmgVolume, userTier: .internalTier)
        ))
        let action = try payload(SystemExtensionEvent(
            .relocationPromptAction(.openedFinder),
            context: .init(installLocation: .translocated, userTier: .free)
        ))

        #expect(display.dimensions == [
            "entry_point": "profile_create",
            "install_location": "dmg_volume",
            "user_tier": "internal",
        ])
        #expect(action.dimensions == [
            "prompt_action": "opened_finder",
            "install_location": "translocated",
            "user_tier": "free",
        ])
    }

    // MARK: - Dimension values

    @Test(
        "The install location comes from the shape of the bundle path",
        arguments: [
            ("/Applications/ProtonVPN.app", SystemExtensionEvent.InstallLocation.applications),
            ("/Applications/VPN/ProtonVPN.app", .applications),
            ("/Users/someone/Downloads/ProtonVPN.app", .downloads),
            ("/Volumes/ProtonVPN/ProtonVPN.app", .dmgVolume),
            ("/private/var/folders/ab/xyz/T/AppTranslocation/1234/d/ProtonVPN.app", .translocated),
            ("/Users/someone/Applications/ProtonVPN.app", .other),
            ("/Users/someone/Desktop/ProtonVPN.app", .other),
        ]
    )
    func installLocation(bundlePath: String, expected: SystemExtensionEvent.InstallLocation) {
        #expect(SystemExtensionEvent.InstallLocation(bundlePath: bundlePath) == expected)
    }

    @Test("The protocol uses the names vpn.any.connection sends")
    func protocolName() {
        #expect(SystemExtensionEvent.ProtocolName(.vpnProtocol(.ike))?.rawValue == "ikev2")
        #expect(SystemExtensionEvent.ProtocolName(.vpnProtocol(.wireGuard(.udp)))?.rawValue == "wireguard_udp")
        #expect(SystemExtensionEvent.ProtocolName(.vpnProtocol(.wireGuard(.tcp)))?.rawValue == "wireguard_tcp")
        #expect(SystemExtensionEvent.ProtocolName(.smartProtocol) == nil)
    }

    // MARK: - Reporter

    /// Collects what the reporter sends, from any location the test moves the app to.
    private final class ReporterHarness {
        var installLocation = SystemExtensionEvent.InstallLocation.downloads
        var sent: [SystemExtensionEvent] = []
        lazy var reporter = TelemetrySystemExtensionReporter(
            send: { [unowned self] in sent.append($0) },
            userTier: { .free },
            installLocation: { [unowned self] in installLocation }
        )
    }

    private func withIsolatedStorage(_ operation: () async throws -> Void) async throws {
        let suiteName = "SystemExtensionEventTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try await withDependencies {
            $0.defaultAppStorage = defaults
        } operation: {
            try await operation()
        }
    }

    private func installResult(
        _ outcome: SystemExtensionEvent.InstallOutcome,
        connectionProtocol: ConnectionProtocol = .vpnProtocol(.wireGuard(.udp))
    ) -> SystemExtensionEvent.Report {
        .installResult(
            origin: origin,
            extensionType: .wireGuard,
            outcome: outcome,
            connectionProtocol: connectionProtocol,
            timeToResult: 2
        )
    }

    @Test("A successful activation from /Applications after the prompt reports the prompt as resolved, once")
    func promptResolvedAfterMovingTheApp() async throws {
        try await withIsolatedStorage {
            let harness = ReporterHarness()

            try await harness.reporter.report(.relocationPromptDisplay(entryPoint: .protocolChange))
            harness.installLocation = .applications
            try await harness.reporter.report(installResult(.installed))
            try await harness.reporter.report(installResult(.alreadyThere(isExtensionActive: true)))

            #expect(harness.sent.map(\.event) == [
                .relocationPromptDisplay, .installResult, .relocationPromptAction, .installResult,
            ])
            // The resolved action names the location the prompt was shown for.
            #expect(harness.sent[2] == SystemExtensionEvent(
                .relocationPromptAction(.resolved),
                context: .init(installLocation: .downloads, userTier: .free)
            ))
        }
    }

    @Test("A failed activation from /Applications leaves the prompt unresolved")
    func promptStaysUnresolvedAfterAFailure() async throws {
        try await withIsolatedStorage {
            let harness = ReporterHarness()

            try await harness.reporter.report(.relocationPromptDisplay(entryPoint: .connectionSettings))
            harness.installLocation = .applications
            try await harness.reporter.report(installResult(.failed(.validationFailed)))
            try await harness.reporter.report(installResult(.userDeclined))

            #expect(!harness.sent.map(\.event).contains(.relocationPromptAction))
        }
    }

    @Test("A prompt shown while in /Applications has nothing to resolve later")
    func promptInApplicationsIsNotTracked() async throws {
        try await withIsolatedStorage {
            let harness = ReporterHarness()
            harness.installLocation = .applications

            try await harness.reporter.report(.relocationPromptDisplay(entryPoint: .profileCreate))
            try await harness.reporter.report(installResult(.installed))

            #expect(harness.sent.map(\.event) == [.relocationPromptDisplay, .installResult])
        }
    }
}
