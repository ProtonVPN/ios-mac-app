//
//  Created on 2022-07-26.
//
//  Copyright (c) 2022 Proton AG
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

#if os(macOS)
    import Foundation
    @testable import LegacyCommon
    import XCTest

    import Dependencies

    import SystemExtensions
    import Telemetry
    import VPNAppCore
    import VPNSharedTesting

    class SystemExtensionManagerTests: XCTestCase {
        let expectationTimeout: TimeInterval = 10

        @Dependency(\.propertiesManager) private var propertiesManager
        var alertService: CoreAlertServiceDummy!
        var sysextManager: SystemExtensionManagerMock!
        var profileManager: ProfileManager!

        private let testOrigin = SystemExtensionEvent.Origin(entryPoint: .connectionSettings, isUserInitiated: true)
        private let telemetryReports = LockIsolated<[SystemExtensionEvent.Report]>([])
        private let telemetryReported = LockIsolated<XCTestExpectation?>(nil)

        override func invokeTest() {
            // A whole value, so that the live telemetry service, with its event observers, is never created.
            var telemetryService = TelemetryService()
            telemetryService.systemExtensionEvent = { [telemetryReports, telemetryReported] report in
                telemetryReports.withValue { $0.append(report) }
                telemetryReported.value?.fulfill()
            }
            withDependencies {
                $0.date.now = Date(timeIntervalSince1970: 0)
                $0.telemetryService = telemetryService
            } operation: {
                super.invokeTest()
            }
        }

        /// Returns an expectation that is fulfilled once `count` telemetry reports have arrived.
        private func expectTelemetryReports(_ count: Int) -> XCTestExpectation {
            let expectation = XCTestExpectation(description: "\(count) telemetry reports")
            expectation.expectedFulfillmentCount = count
            expectation.assertForOverFulfill = false
            telemetryReported.setValue(expectation)
            return expectation
        }

        override func setUp() {
            super.setUp()
            alertService = CoreAlertServiceDummy()
            sysextManager = SystemExtensionManagerMock(factory: self)
            profileManager = ProfileManager(
                profileStorage: ProfileStorage()
            )

            propertiesManager.smartProtocol = true
        }

        override func tearDown() {
            super.tearDown()
            alertService = nil
            sysextManager = nil
            profileManager = nil
        }

        func testInstallingExtensionForTheFirstTimeSimply() {
            let approvalRequired = SystemExtensionType.allCases.filter(\.featureEnabled).map { XCTestExpectation(description: "Approval required for \($0.rawValue)") }
            let installFinished = XCTestExpectation(description: "Finish install")
            let alertShown = XCTestExpectation(description: "alertShown")
            alertShown.expectedFulfillmentCount = 2
            var result: SystemExtensionResult?

            alertService.alertAdded = { _ in
                alertShown.fulfill()
            }

            sysextManager.requestRequiresUserApproval = { [unowned self] request in
                sysextManager.approve(request: request)
                approvalRequired.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
            }

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(origin: testOrigin, shouldStartTour: true, includedTypes: SystemExtensionType.allCases) { installResult, _ in
                result = installResult
                installFinished.fulfill()
            }

            wait(for: approvalRequired.appending(alertShown), timeout: expectationTimeout)

            guard alertService.alerts.count == 2,
                  alertService.alerts.contains(where: { $0 is SystemExtensionTourAlert }),
                  alertService.alerts.contains(where: { $0 is SysexEnabledAlert }) else {
                XCTFail("Expected alerts to be SystemExtensionTourAlert and SysexEnabledAlert: \(String(describing: alertService.alerts))")
                return
            }

            wait(for: [installFinished], timeout: expectationTimeout)

            guard case .success(.installed) = result else {
                XCTFail("Expected system extensions to install successfully but got \(String(describing: result))")
                return
            }

            XCTAssertEqual(sysextManager.installedExtensions.count, 1, "Should have installed one extension")
            XCTAssert(
                sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue },
                "Should have installed WireGuard extension"
            )
        }

        func testInstallingExtensionForTheFirstTimeSubmittingMultipleRequests() {
            let approvalRequired = SystemExtensionType.allCases.filter(\.featureEnabled).map { XCTestExpectation(description: "Approval required for \($0.rawValue)") }
            var initialRequests: [SystemExtensionRequest] = []

            let installFinished = XCTestExpectation(description: "Finish install")
            var installResult: SystemExtensionResult?

            sysextManager.requestRequiresUserApproval = { request in
                // Don't approve the requests for now, we want to see how multiple requests coalesce.
                initialRequests.append(request)
                approvalRequired.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
            }

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(origin: testOrigin, shouldStartTour: true, includedTypes: SystemExtensionType.allCases) { result, _ in
                installResult = result
                installFinished.fulfill()
            }

            wait(for: approvalRequired, timeout: expectationTimeout)

            sysextManager.requestRequiresUserApproval = { _ in
                XCTFail("Request should have been cancelled, shouldn't ask for user approval")
            }

            let nAttempts = 10
            for attempt in 1 ... nAttempts {
                var cancelResult: SystemExtensionResult?
                let installCancelled = XCTestExpectation(description: "Cancel install attempt #\(attempt)")

                sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(origin: testOrigin, shouldStartTour: true, includedTypes: SystemExtensionType.allCases) { result, _ in
                    cancelResult = result
                    installCancelled.fulfill()
                }
                wait(for: [installCancelled], timeout: expectationTimeout)

                guard case .failure(.tourCancelled) = cancelResult else {
                    XCTFail("Expected second request to be treated as a cancelled tour, but got \(String(describing: cancelResult)) instead")
                    continue
                }
            }

            for request in initialRequests {
                sysextManager.approve(request: request)
            }

            guard alertService.alerts.count == 1, alertService.alerts.first is SystemExtensionTourAlert else {
                XCTFail("Expected only alert to be SystemExtensionTourAlert: \(String(describing: alertService.alerts))")
                return
            }

            wait(for: [installFinished], timeout: expectationTimeout)

            guard case .success(.installed) = installResult else {
                XCTFail("Expected system extensions to install successfully but got \(String(describing: installResult))")
                return
            }

            XCTAssertEqual(sysextManager.installedExtensions.count, 1, "Should have installed one extension")
            XCTAssert(
                sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue },
                "Should have installed WireGuard extension"
            )
        }

        func testNewVersionOfExtensionGetsUpgraded() {
            sysextManager.installedExtensions = [
                .init(version: "1.2.3", build: "1", bundleId: SystemExtensionType.wireGuard.rawValue),
            ]
            sysextManager.mockVersions = ("1.2.4", "1")

            let installFinished = XCTestExpectation(description: "Finish install")
            var result: SystemExtensionResult?

            sysextManager.requestRequiresUserApproval = { _ in
                XCTFail("Shouldn't need to request for approval, extensions are being upgraded")
            }

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(origin: testOrigin, shouldStartTour: true, includedTypes: SystemExtensionType.allCases) { installResult, _ in
                result = installResult
                installFinished.fulfill()
            }

            wait(for: [installFinished], timeout: expectationTimeout)

            guard case .success(.upgraded) = result else {
                XCTFail("Expected system extensions to upgrade but got \(String(describing: result))")
                return
            }

            XCTAssertEqual(sysextManager.installedExtensions.count, 1, "Should have installed one extension")
            XCTAssert(
                sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue && $0.version == sysextManager.mockVersions?.semanticVersion },
                "Should have installed WireGuard extension"
            )
        }

        func testUninstall() {
            sysextManager.installedExtensions = [
                .init(version: "1.2.3", build: "1", bundleId: SystemExtensionType.wireGuard.rawValue),
            ]

            _ = sysextManager.uninstallAll(userInitiated: true)

            XCTAssertEqual(
                sysextManager.installedExtensions.count,
                0,
                "Extensions should have been uninstalled"
            )
        }

        func testInstallationErrorWrongLocationForApplication() {
            let installFinished = XCTestExpectation(description: "Wait for installation error")
            var result: SystemExtensionResult?

            let requestPending = SystemExtensionType.allCases.filter(\.featureEnabled).map { XCTestExpectation(description: "Request pending for \($0.rawValue)") }
            var initialRequests: [SystemExtensionRequest] = []

            sysextManager.requestIsPending = { request in
                initialRequests.append(request)
                requestPending.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
            }

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(origin: testOrigin, shouldStartTour: true, includedTypes: SystemExtensionType.allCases) { installResult, _ in
                result = installResult
                installFinished.fulfill()
            }

            wait(for: requestPending, timeout: expectationTimeout)

            for initialRequest in initialRequests {
                sysextManager.fail(request: initialRequest, withError: OSSystemExtensionError(.unsupportedParentBundleLocation))
            }

            wait(for: [installFinished], timeout: expectationTimeout)

            guard case let .failure(.installationError(internalError: error)) = result,
                  let sysextError = error as? OSSystemExtensionError,
                  sysextError.code == .unsupportedParentBundleLocation else {
                XCTFail("Installation should have failed with parent bundle error, got: \(String(describing: result))")
                return
            }
        }

        func testTourSkippedWhenShouldStartTourIsFalse() {
            let installFinished = XCTestExpectation(description: "Finish install")
            var result: SystemExtensionResult?

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(origin: testOrigin, shouldStartTour: false, includedTypes: SystemExtensionType.allCases) { installResult, _ in
                result = installResult
                installFinished.fulfill()
            }

            XCTAssertEqual(alertService.alerts.count, 0, "No alerts should be shown when 'shouldStartTour' is false")

            wait(for: [installFinished], timeout: expectationTimeout)

            guard case .failure(.tourSkipped) = result else {
                XCTFail("Expected tour skipped but got: \(String(describing: result))")
                return
            }

            XCTAssertEqual(sysextManager.installedExtensions.count, 0, "No extensions should be installed when tour was skipped")
        }

        func testInstallingOnlyWireGuardExtensionWhenSubsetProvided() {
            let approvalRequired = XCTestExpectation(description: "Approval required for wireguard")
            let installFinished = XCTestExpectation(description: "Finish install")
            let alertShown = XCTestExpectation(description: "alertShown")
            alertShown.expectedFulfillmentCount = 2
            var result: SystemExtensionResult?

            alertService.alertAdded = { _ in
                alertShown.fulfill()
            }

            sysextManager.requestRequiresUserApproval = { [unowned self] request in
                sysextManager.approve(request: request)
                if request.request.identifier == SystemExtensionType.wireGuard.rawValue {
                    approvalRequired.fulfill()
                }
            }

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(
                origin: testOrigin,
                shouldStartTour: true,
                includedTypes: [.wireGuard]
            ) { installResult, _ in
                result = installResult
                installFinished.fulfill()
            }

            wait(for: [approvalRequired, alertShown, installFinished], timeout: expectationTimeout)

            guard case .success(.installed) = result else {
                XCTFail("Expected system extensions to install successfully but got \(String(describing: result))")
                return
            }

            XCTAssertEqual(sysextManager.installedExtensions.count, 1, "Should have installed one extension")
            XCTAssert(
                sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue },
                "Should have installed WireGuard extension"
            )
        }

        // MARK: - Telemetry

        func testApprovingWhileTheTourIsOpenReportsItAsProceeded() {
            let pendingRequest = LockIsolated<SystemExtensionRequest?>(nil)
            sysextManager.requestRequiresUserApproval = { request in
                pendingRequest.setValue(request)
            }
            // The installation shows the tour, and the enabled alert once it finishes. Waiting for both keeps that
            // work from reaching this test case after tearDown.
            let tourShown = XCTestExpectation(description: "Tour shown")
            let enabledAlertShown = XCTestExpectation(description: "Enabled alert shown")
            alertService.alertAdded = { alert in
                if alert is SystemExtensionTourAlert {
                    tourShown.fulfill()
                } else {
                    enabledAlertShown.fulfill()
                }
            }
            let installFinished = XCTestExpectation(description: "Finish install")
            // The attempt and the shown tour.
            let displayed = expectTelemetryReports(2)

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(
                origin: testOrigin,
                shouldStartTour: true,
                includedTypes: [.wireGuard]
            ) { _, _ in installFinished.fulfill() }
            wait(for: [tourShown, displayed], timeout: expectationTimeout)

            let approved = expectTelemetryReports(2)
            if let request = pendingRequest.value {
                sysextManager.approve(request: request)
            }
            wait(for: [approved, enabledAlertShown, installFinished], timeout: expectationTimeout)

            XCTAssert(telemetryReports.value.contains(display))
            XCTAssertEqual(telemetryReports.value.filter(isAnswerOrResult), [
                .approvalPromptAction(origin: testOrigin, extensionType: .wireGuard, outcome: .proceeded),
                result(.installed),
            ])
        }

        private var display: SystemExtensionEvent.Report {
            .approvalPromptDisplay(origin: testOrigin, extensionType: .wireGuard)
        }

        private func result(_ outcome: SystemExtensionEvent.InstallOutcome) -> SystemExtensionEvent.Report {
            .installResult(
                origin: testOrigin,
                extensionType: .wireGuard,
                outcome: outcome,
                connectionProtocol: .smartProtocol,
                timeToResult: 0
            )
        }

        func testClosingTheTourReportsItAsCancelledAndTheRequestAsDeclinedOnce() {
            let reported = expectTelemetryReports(4)
            var pendingRequest: SystemExtensionRequest?
            let approvalRequired = XCTestExpectation(description: "Approval required")
            sysextManager.requestRequiresUserApproval = { request in
                pendingRequest = request
                approvalRequired.fulfill()
            }
            let tourShown = XCTestExpectation(description: "Tour shown")
            alertService.alertAdded = { alert in
                if alert is SystemExtensionTourAlert {
                    tourShown.fulfill()
                }
            }

            // The handler runs once when the tour is closed, and again when the approval finishes the request.
            let handlerCalled = XCTestExpectation(description: "Result handler called twice")
            handlerCalled.expectedFulfillmentCount = 2

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(
                origin: testOrigin,
                shouldStartTour: true,
                includedTypes: [.wireGuard]
            ) { _, _ in handlerCalled.fulfill() }
            wait(for: [approvalRequired, tourShown], timeout: expectationTimeout)

            let tour = alertService.alerts.lazy.compactMap { $0 as? SystemExtensionTourAlert }.first
            tour?.cancelHandler()
            wait(for: [reported], timeout: expectationTimeout)

            // Approving the same request later is not reported again.
            let approvedLater = expectTelemetryReports(1)
            approvedLater.isInverted = true
            if let pendingRequest {
                sysextManager.approve(request: pendingRequest)
            }
            wait(for: [handlerCalled], timeout: expectationTimeout)
            wait(for: [approvedLater], timeout: 1)

            XCTAssert(telemetryReports.value.contains(display))
            XCTAssertEqual(telemetryReports.value.filter(isAnswerOrResult), [
                .approvalPromptAction(origin: testOrigin, extensionType: .wireGuard, outcome: .cancelled),
                result(.userDeclined),
            ])
        }

        func testOpeningSystemSettingsFromTheTourReportsItAsProceededAndClosingItDeclinesNothing() {
            let pendingRequest = LockIsolated<SystemExtensionRequest?>(nil)
            let approvalRequired = XCTestExpectation(description: "Approval required")
            sysextManager.requestRequiresUserApproval = { request in
                pendingRequest.setValue(request)
                approvalRequired.fulfill()
            }
            let tourShown = XCTestExpectation(description: "Tour shown")
            alertService.alertAdded = { alert in
                if alert is SystemExtensionTourAlert {
                    tourShown.fulfill()
                }
            }
            let handlerCalled = XCTestExpectation(description: "Result handler called twice")
            handlerCalled.expectedFulfillmentCount = 2
            // The attempt, the shown tour, and the proceeded tour.
            let proceeded = expectTelemetryReports(3)

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(
                origin: testOrigin,
                shouldStartTour: true,
                includedTypes: [.wireGuard]
            ) { _, _ in handlerCalled.fulfill() }
            wait(for: [approvalRequired, tourShown], timeout: expectationTimeout)

            let tour = alertService.alerts.lazy.compactMap { $0 as? SystemExtensionTourAlert }.first
            tour?.openedSystemSettingsHandler()
            tour?.cancelHandler()
            wait(for: [proceeded], timeout: expectationTimeout)

            let approved = expectTelemetryReports(1)
            if let request = pendingRequest.value {
                sysextManager.approve(request: request)
            }
            wait(for: [handlerCalled, approved], timeout: expectationTimeout)

            XCTAssert(telemetryReports.value.contains(display))
            XCTAssertEqual(telemetryReports.value.filter(isAnswerOrResult), [
                .approvalPromptAction(origin: testOrigin, extensionType: .wireGuard, outcome: .proceeded),
                result(.installed),
            ])
        }

        func testNotShowingTheTourReportsItAsSkipped() {
            let pendingRequest = LockIsolated<SystemExtensionRequest?>(nil)
            sysextManager.requestRequiresUserApproval = { request in
                pendingRequest.setValue(request)
            }
            let handlerCalled = XCTestExpectation(description: "Result handler called twice")
            handlerCalled.expectedFulfillmentCount = 2
            // The attempt and the skipped tour.
            let skipped = expectTelemetryReports(2)

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(
                origin: testOrigin,
                shouldStartTour: false,
                includedTypes: [.wireGuard]
            ) { _, _ in handlerCalled.fulfill() }
            wait(for: [skipped], timeout: expectationTimeout)

            // The user can still approve the extension on their own, which reports the result.
            let approved = expectTelemetryReports(1)
            if let request = pendingRequest.value {
                sysextManager.approve(request: request)
            }
            wait(for: [handlerCalled, approved], timeout: expectationTimeout)

            // The app never showed the tour.
            XCTAssertFalse(telemetryReports.value.contains(display))
            XCTAssertEqual(telemetryReports.value.filter(isAnswerOrResult), [
                .approvalPromptAction(origin: testOrigin, extensionType: .wireGuard, outcome: .skipped),
                result(.installed),
            ])
        }

        /// Leaves out the attempt and the shown tour, which are sent from their own tasks and can arrive in any order.
        private func isAnswerOrResult(_ report: SystemExtensionEvent.Report) -> Bool {
            switch report {
            case .installAttempt, .approvalPromptDisplay:
                false
            default:
                true
            }
        }

        func testOutcomeOfEachFinalState() {
            typealias Activation = SystemExtensionActivationTelemetry
            let completed = SystemExtensionRequest.State.succeeded(.completed)
            let badLocation = OSSystemExtensionError(.unsupportedParentBundleLocation)
            let authorizationRequired = OSSystemExtensionError(.authorizationRequired)

            XCTAssertEqual(Activation.outcome(for: completed, installedCopy: nil), .installed)
            XCTAssertEqual(Activation.outcome(for: completed, installedCopy: .replacedOlderVersion), .upgraded)
            XCTAssertEqual(
                Activation.outcome(for: completed, installedCopy: .reinstalled(isEnabled: true)),
                .alreadyThere(isExtensionActive: true)
            )
            XCTAssertEqual(
                Activation.outcome(for: .cancelled, installedCopy: .kept(isEnabled: false)),
                .alreadyThere(isExtensionActive: false)
            )
            XCTAssertEqual(
                Activation.outcome(for: .cancelled, installedCopy: nil),
                .alreadyThere(isExtensionActive: nil)
            )
            XCTAssertEqual(
                Activation.outcome(for: .failed(badLocation), installedCopy: nil),
                .failed(.unsupportedParentBundleLocation)
            )
            XCTAssertEqual(
                Activation.outcome(for: .failed(authorizationRequired), installedCopy: nil),
                .failed(.authorizationRequired)
            )
            XCTAssertEqual(SystemExtensionEvent.ErrorCode(authorizationRequired).rawValue, "SXAR")
            XCTAssertEqual(
                Activation.outcome(for: .failed(OSSystemExtensionError(.missingEntitlement)), installedCopy: nil),
                .failed(.missingEntitlement)
            )
            XCTAssertEqual(SystemExtensionEvent.ErrorCode(NSError(domain: NSCocoaErrorDomain, code: 1)), .unknown)
            XCTAssertNil(Activation.outcome(for: .superseded, installedCopy: nil))
            XCTAssertNil(Activation.outcome(for: .userActionRequired, installedCopy: nil))
        }
    }

    class ExtensionInfoComparisonTests: XCTestCase {
        func info(_ version: String, _ buildNumber: String) -> ExtensionInfo {
            ExtensionInfo(version: version, build: buildNumber, bundleId: "me.proton.jetpack")
        }

        func testEquals() {
            let info1 = info("1.2.3", "202030.1210311620")
            let info2 = info("1.2.3", "202030.1210311620")

            XCTAssertEqual(info1.compare(to: info2), .orderedSame)
        }

        func testLessThan() {
            do {
                let info1 = info("1.2.3", "1210311620")
                let info2 = info("1.2.4", "1210311620")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1234567.1210311620")
                let info2 = info("1.2.4", "1210311620")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1234568.1210311620")
                let info2 = info("1.2.4", "1234567.1210311622")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1210311620")
                let info2 = info("1.2.3", "1210311621")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1234567.1210311620")
                let info2 = info("1.2.3", "1234567.1210311621")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1234567.1210311620")
                let info2 = info("1.2.3", "1234568.1210311620")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1234567.1210311622")
                let info2 = info("1.2.3", "1234568.1210311620")
                XCTAssertLessThan(info1, info2)
            }

            do {
                let info1 = info("1.2.3", "1234567")
                let info2 = info("1.2.3", "1234567.1210311620")
                XCTAssertLessThan(info1, info2)
            }
        }
    }

    extension SystemExtensionManagerTests: SystemExtensionManager.Factory {
        func makeCoreAlertService() -> CoreAlertService {
            alertService
        }

        func makeProfileManager() -> ProfileManager {
            profileManager
        }
    }
#endif
