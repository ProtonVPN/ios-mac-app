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
import XCTest
@testable import LegacyCommon

import SystemExtensions
import VPNSharedTesting

class SystemExtensionManagerTests: XCTestCase {
    let expectationTimeout: TimeInterval = 10

    var propertiesManager: PropertiesManagerMock!
    var vpnKeychain: VpnKeychainMock!
    var alertService: CoreAlertServiceDummy!
    var sysextManager: SystemExtensionManagerMock!
    var profileManager: ProfileManager!

    override func setUp() {
        super.setUp()
        propertiesManager = PropertiesManagerMock()
        alertService = CoreAlertServiceDummy()
        vpnKeychain = VpnKeychainMock(planName: "free", maxTier: .freeTier)
        sysextManager = SystemExtensionManagerMock(factory: self)
        profileManager = ProfileManager(propertiesManager: propertiesManager,
                                        profileStorage: ProfileStorage(authKeychain: MockAuthKeychain()))

        propertiesManager.smartProtocol = true
    }

    override func tearDown() {
        super.tearDown()
        propertiesManager = nil
        alertService = nil
        vpnKeychain = nil
        sysextManager = nil
        profileManager = nil
    }

    func testInstallingExtensionForTheFirstTimeSimply() {
        let approvalRequired = SystemExtensionType.allCases.map { XCTestExpectation(description: "Approval required for \($0.rawValue)") }
        let installFinished = XCTestExpectation(description: "Finish install")
        var result: SystemExtensionResult?

        sysextManager.requestRequiresUserApproval = { [unowned self] request in
            self.sysextManager.approve(request: request)
            approvalRequired.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
        }

        sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: true) { installResult in
            result = installResult
            installFinished.fulfill()
        }

        wait(for: approvalRequired, timeout: expectationTimeout)

        guard alertService.alerts.count == 1, alertService.alerts.first is SystemExtensionTourAlert else {
            XCTFail("Expected only alert to be SystemExtensionTourAlert: \(String(describing: alertService.alerts))")
            return
        }

        wait(for: [installFinished], timeout: expectationTimeout)

        guard case .success(.installed) = result else {
            XCTFail("Expected system extensions to install successfully but got \(String(describing: result))")
            return
        }

        XCTAssertEqual(sysextManager.installedExtensions.count, 1, "Should have installed one extension")
        XCTAssert(sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue },
                  "Should have installed WireGuard extension")
    }

    func testInstallingExtensionForTheFirstTimeSubmittingMultipleRequests() {
        let approvalRequired = SystemExtensionType.allCases.map { XCTestExpectation(description: "Approval required for \($0.rawValue)") }
        var initialRequests: [SystemExtensionRequest] = []

        let installFinished = XCTestExpectation(description: "Finish install")
        var installResult: SystemExtensionResult?

        sysextManager.requestRequiresUserApproval = { request in
            // Don't approve the requests for now, we want to see how multiple requests coalesce.
            initialRequests.append(request)
            approvalRequired.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
        }

        sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: true) { result in
            installResult = result
            installFinished.fulfill()
        }

        wait(for: approvalRequired, timeout: expectationTimeout)

        sysextManager.requestRequiresUserApproval = { request in
            XCTFail("Request should have been cancelled, shouldn't ask for user approval")
        }

        let nAttempts = 10
        (1...nAttempts).forEach { attempt in
            var cancelResult: SystemExtensionResult?
            let installCancelled = XCTestExpectation(description: "Cancel install attempt #\(attempt)")

            sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: true) { result in
                cancelResult = result
                installCancelled.fulfill()
            }
            wait(for: [installCancelled], timeout: expectationTimeout)

            guard case .success(.alreadyThere) = cancelResult else {
                XCTFail("Expected second request to be cancelled, but got \(String(describing: cancelResult)) instead")
                return
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
        XCTAssert(sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue },
                  "Should have installed WireGuard extension")
    }

    func testNewVersionOfExtensionGetsUpgraded() {
        sysextManager.installedExtensions = [
            .init(version: "1.2.3", build: "1", bundleId: SystemExtensionType.wireGuard.rawValue),
        ]
        sysextManager.mockVersions = ("1.2.4", "1")

        let installFinished = XCTestExpectation(description: "Finish install")
        var result: SystemExtensionResult?

        sysextManager.requestRequiresUserApproval = { request in
            XCTFail("Shouldn't need to request for approval, extensions are being upgraded")
        }

        sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: true) { installResult in
            result = installResult
            installFinished.fulfill()
        }

        wait(for: [installFinished], timeout: expectationTimeout)

        guard case .success(.upgraded) = result else {
            XCTFail("Expected system extensions to upgrade but got \(String(describing: result))")
            return
        }

        XCTAssertEqual(sysextManager.installedExtensions.count, 1, "Should have installed one extension")
        XCTAssert(sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue && $0.version == sysextManager.mockVersions?.semanticVersion },
                  "Should have installed WireGuard extension")
    }

    func testUninstall() {
        sysextManager.installedExtensions = [
            .init(version: "1.2.3", build: "1", bundleId: SystemExtensionType.wireGuard.rawValue),
        ]

        _ = sysextManager.uninstallAll(userInitiated: true)

        XCTAssertEqual(sysextManager.installedExtensions.count, 0,
                       "Extensions should have been uninstalled")
    }

    func testInstallationErrorWrongLocationForApplication() {
        let installFinished = XCTestExpectation(description: "Wait for installation error")
        var result: SystemExtensionResult?

        let requestPending = SystemExtensionType.allCases.map { XCTestExpectation(description: "Request pending for \($0.rawValue)") }
        var initialRequests: [SystemExtensionRequest] = []

        sysextManager.requestIsPending = { request in
            initialRequests.append(request)
            requestPending.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
        }

        sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: true) { installResult in
            result = installResult
            installFinished.fulfill()
        }

        wait(for: requestPending, timeout: expectationTimeout)

        initialRequests.forEach {
            sysextManager.fail(request: $0, withError: OSSystemExtensionError(.unsupportedParentBundleLocation))
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

        sysextManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: false) { installResult in
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
}

extension SystemExtensionManagerTests: SystemExtensionManager.Factory {
    func makeCoreAlertService() -> CoreAlertService {
        return alertService
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }

    func makeVpnKeychain() -> VpnKeychainProtocol {
        return vpnKeychain
    }

    func makeProfileManager() -> ProfileManager {
        return profileManager
    }
}
#endif
