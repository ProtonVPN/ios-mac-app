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

#if os(macOS) && DEBUG
import Foundation
import SystemExtensions

public class SystemExtensionManagerMock: SystemExtensionManager {
    public var pendingRequests: [(SystemExtensionRequest, ExtensionInfo)] = []
    public var installedExtensions: [ExtensionInfo] = []

    public var requestIsPending: ((SystemExtensionRequest) -> Void)?
    public var requestRequiresUserApproval: ((SystemExtensionRequest) -> Void)?
    public var requestFinished: ((SystemExtensionRequest) -> Void)?

    public typealias VersionString = String
    public typealias BundleVersions = (semanticVersion: VersionString, buildVersion: VersionString)

    public var mockVersions: BundleVersions?

    public lazy var bundleAppVersions: BundleVersions = ("4.2.0", "1804201620")

    override public func request(_ request: SystemExtensionRequest) {
        guard case .install = request.action else {
            guard case .uninstall = request.action else { return }

            installedExtensions.removeAll { $0.bundleId == request.request.identifier }

            requestFinished?(request)
            request.request(request.request, didFinishWithResult: .completed)
            return
        }

        let extensionVersion = mockVersions ?? bundleAppVersions
        let extensionInfo = ExtensionInfo(version: extensionVersion.semanticVersion,
                                          build: extensionVersion.buildVersion,
                                          bundleId: request.request.identifier)
        // ExtensionInfo's Comparable function only matches on version info, we need to compare bundleId as well.
        let matchesExtensionInfo = { (info: ExtensionInfo) in
            info == extensionInfo && info.bundleId == extensionInfo.bundleId
        }

        if let pending = pendingRequests.first(where: { (_, info) in matchesExtensionInfo(info) }) {
            guard request.shouldExtension(pending.1, beReplacedBy: extensionInfo) else {
                request.request(request.request, didFailWithError: OSSystemExtensionError(.requestCanceled))
                requestFinished?(request)
                return
            }

            pending.0.request(pending.0.request, didFailWithError: OSSystemExtensionError(.requestSuperseded))
            pendingRequests.removeAll { (pendingRequest, _) in pendingRequest.uuid == pending.0.uuid }
        }

        pendingRequests.append((request, extensionInfo))
        requestIsPending?(request)

        if let installed = installedExtensions.first(where: { $0.bundleId == extensionInfo.bundleId }) {
            guard request.shouldExtension(installed, beReplacedBy: extensionInfo) else {
                pendingRequests.removeAll { (pendingRequest, _) in pendingRequest.uuid == request.uuid }
                request.request(request.request, didFailWithError: OSSystemExtensionError(.requestCanceled))
                requestFinished?(request)
                return
            }

            installedExtensions.removeAll { $0.bundleId == extensionInfo.bundleId }
            installedExtensions.append(extensionInfo)

            pendingRequests.removeAll { (pendingRequest, _) in pendingRequest.uuid == request.uuid }
            request.request(request.request, didFinishWithResult: .completed)
            requestFinished?(request)
            return
        }

        request.requestNeedsUserApproval(request.request)
        requestRequiresUserApproval?(request)
    }

    public func approve(request: SystemExtensionRequest) {
        var info: ExtensionInfo?
        pendingRequests.removeAll { (pendingRequest, pendingInfo) in
            guard pendingRequest.uuid == request.uuid else {
                return false
            }

            info = pendingInfo // save the item before removing it
            return true
        }

        guard let info = info else {
            log.assertionFailure("Attempted to approve a request that wasn't in pending requests")
            return
        }

        installedExtensions.append(info)
        request.request(request.request, didFinishWithResult: .completed)
        requestFinished?(request)
    }

    public func fail(request: SystemExtensionRequest, withError error: Error) {
        pendingRequests.removeAll { (pendingRequest, _) in pendingRequest.uuid == request.uuid }
        request.request(request.request, didFailWithError: error)
        requestFinished?(request)
    }
}
#endif
