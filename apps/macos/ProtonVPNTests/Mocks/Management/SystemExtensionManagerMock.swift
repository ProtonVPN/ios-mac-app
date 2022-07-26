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
import SystemExtensions
import XCTest
@testable import ProtonVPN

class SystemExtensionManagerMock: SystemExtensionManager {
    var pendingRequests: [(SystemExtensionRequest, SystemExtensionInfo)] = []
    var installedExtensions: [SystemExtensionInfo] = []

    typealias VersionString = String
    typealias BundleVersions = (semanticVersion: VersionString, buildVersion: VersionString)

    var mockVersions: BundleVersions?

    var bundleAppVersions: BundleVersions {
        let macAppBundle = Bundle(for: SystemExtensionManagerImplementation.self)
        guard let buildVersion = macAppBundle.infoDictionary?["CFBundleShortVersionString"] as? String else {
            fatalError("Bundle has no build version?")
        }
        guard let bundleVersion = macAppBundle.infoDictionary?["CFBundleVersion"] as? String else {
            fatalError("Bundle has no version?")
        }

        return (bundleVersion, buildVersion)
    }

    func extensionStatus(forType type: SystemExtensionType, completion: @escaping StatusCallback) {
        return
    }

    func extensionStatuses(resultHandler: @escaping ([SystemExtensionType : SystemExtensionStatus]) -> Void) {
        return
    }

    func request(_ request: SystemExtensionRequest) {
        let extensionVersion = mockVersions ?? bundleAppVersions
        let extensionInfo = SystemExtensionInfo(type: request.type,
                                                bundleVersion: extensionVersion.semanticVersion,
                                                buildVersion: extensionVersion.buildVersion)

        if let pending = pendingRequests.first(where: { (_, info) in info == extensionInfo }) {
            let action = request.actionForReplacing(existingExtension: pending.1, with: extensionInfo)
            switch action {
            case .cancel:
                request.didFinish(withResult: .failure(OSSystemExtensionError(.requestCanceled)))
                return
            case .replace:
                pending.0.didFinish(withResult: .failure(OSSystemExtensionError(.requestSuperseded)))
                pendingRequests.removeAll { (_, info) in info == pending.1 }
                pendingRequests.append((request, extensionInfo))
            }
        }

        if let installed = installedExtensions.first(where: { info in info == extensionInfo }) {
            let action = request.actionForReplacing(existingExtension: installed, with: extensionInfo)
            switch action {
            case .cancel:
                request.didFinish(withResult: .failure(OSSystemExtensionError(.requestCanceled)))
            case .replace:
                installedExtensions.removeAll { info in info == installed }
                installedExtensions.append(extensionInfo)
                request.didFinish(withResult: .success(.completed))
            }
            return
        }

        request.needsUserApproval()
    }

    func approve(extensionWithInfo ext: SystemExtensionInfo) {
        guard let pending = pendingRequests.first(where: { (request, info) in
            request.state == .userActionRequired && info == ext
        }) else {
            XCTFail("Didn't find pending extension request with info \(ext)")
            return
        }

        XCTAssert(!installedExtensions.contains(where: { $0.type == ext.type }),
                  "Shouldn't need to approve extension when installed extension \(ext.type) already exists")

        pendingRequests.removeAll(where: { (_, info) in info == ext })
        installedExtensions.append(ext)
        pending.0.didFinish(withResult: .success(.completed))
    }

    func failInstallation(forExtensionWithInfo ext: SystemExtensionInfo, withError error: Error) {
        guard let pending = pendingRequests.first(where: { (_, info) in info == ext }) else {
            XCTFail("Didn't find pending extension request with info \(ext)")
            return
        }

        pendingRequests.removeAll(where: { (_, info) in info == ext })
        pending.0.didFinish(withResult: .failure(error))
    }
}

