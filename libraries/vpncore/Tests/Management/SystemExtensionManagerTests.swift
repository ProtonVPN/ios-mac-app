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

import Foundation
import XCTest
@testable import vpncore

class SystemExtensionManagerTests: XCTestCase {
    let expectationTimeout: TimeInterval = 600

    var propertiesManager: PropertiesManagerMock!
    var vpnKeychain: VpnKeychainMock!
    var alertService: CoreAlertService!
    var sysextManager: SystemExtensionManagerMock!

    override func setUp() {
        propertiesManager = PropertiesManagerMock()
        alertService = CoreAlertServiceMock()
        vpnKeychain = VpnKeychainMock(accountPlan: .free, maxTier: CoreAppConstants.VpnTiers.free)
        sysextManager = SystemExtensionManagerMock(factory: self)
    }

    override func tearDown() {
        propertiesManager = nil
        alertService = nil
        vpnKeychain = nil
        sysextManager = nil
    }

    func testInstallingExtensionForTheFirstTimeSimply() {
        let approvalRequired = SystemExtensionType.allCases.map { XCTestExpectation(description: "Approval required for \($0.rawValue)") }
        let installFinished = XCTestExpectation(description: "Finish install")
        var result: SystemExtensionResult?

        sysextManager.requestRequiresUserApproval = { [unowned self] request in
            self.sysextManager.approve(request: request)
            approvalRequired.first(where: { $0.description.contains(request.request.identifier) })?.fulfill()
        }

        sysextManager.checkAndInstallAllIfNeeded(userInitiated: true) { installResult in
            result = installResult
            installFinished.fulfill()
        }

        wait(for: approvalRequired + [installFinished], timeout: expectationTimeout)

        guard case .installed = result else {
            XCTFail("Expected system extensions to install successfully but got \(String(describing: result))")
            return
        }

        XCTAssertEqual(sysextManager.installedExtensions.count, 2, "Should have installed two extensions")
        XCTAssert(sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.wireGuard.rawValue },
                  "Should have installed WireGuard extension")
        XCTAssert(sysextManager.installedExtensions.contains { $0.bundleId == SystemExtensionType.openVPN.rawValue },
                  "Should have installed OpenVPN extension")
    }

    func testInstallingExtensionForTheFirstTimeSubmittingMultipleRequests() {

    }

    func testNewVersionOfExtensionGetsUpgraded() {

    }

    func testInstallationErrorWrongLocationForApplication() {

    }
}

extension SystemExtensionManagerTests: SystemExtensionManager.Factory {
    func makeCoreAlertService() -> CoreAlertService {
        return alertService
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }
}
