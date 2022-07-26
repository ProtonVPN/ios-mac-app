//
//  SystemExtensionManager.swift
//  ProtonVPN - Created on 07/12/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import SystemExtensions
import vpncore

protocol SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager
}

protocol SystemExtensionManager {
    typealias StatusCallback = ((SystemExtensionStatus) -> Void)

    func extensionStatus(forType type: SystemExtensionType, completion: @escaping StatusCallback)
    func extensionStatuses(resultHandler: @escaping ([SystemExtensionType: SystemExtensionStatus]) -> Void)
    func request(_ request: SystemExtensionRequest)
}

protocol SystemExtensionRequestDelegate: class {
    func requestFinished(_ request: SystemExtensionRequest)
}

enum SystemExtensionManagerNotification {
    static let allExtensionsInstalled = Notification.Name("SystemExtensionsAllInstalled")
}

enum SystemExtensionType: String, CaseIterable {
    case openVPN = "ch.protonvpn.mac.OpenVPN-Extension"
    case wireGuard = "ch.protonvpn.mac.WireGuard-Extension"
    
    var machServiceName: String {
        let teamId = Bundle.main.infoDictionary!["TeamIdentifierPrefix"] as! String
        return "\(teamId)group.\(rawValue)"
    }
}

struct SystemExtensionInfo: Equatable {
    let type: SystemExtensionType
    let bundleVersion: String
    let buildVersion: String
}

enum SystemExtensionStatus {
    case notInstalled
    case outdated
    case ok
}

enum SystemExtensionError: String, Error {
    case unrecognizedType
    case mismatchedType
}

/// Wrapper class for both `OSSystemExtensionRequest` and its delegate class. This lets us keep
/// track of individual sysext requests, and determine which requests are initiated by the user vs. started
/// in the background.
class SystemExtensionRequest: NSObject {
    struct RequestAlreadyWaitingError: Error, CustomStringConvertible {
        let description = "Already waiting for user approval for this extension type."
    }

    enum Action: String {
        case install
        case uninstall
    }

    enum State: String {
        /// Request has been submitted, but we haven't gotten a response yet.
        case outstanding
        /// Request has been received, but is waiting on user action to proceed.
        case userActionRequired
        /// User has acted on extension, and we have instructed sysextd to replace an existing extension.
        case replacing
        /// Request has completed successfully.
        case succeeded
        /// Request has failed with an error.
        case failed
        /// Request has been superseded by another one (user requested another sysext install).
        case superseded
    }

    typealias Completion = (Result<OSSystemExtensionRequest.Result, Error>) -> Void

    weak var delegate: SystemExtensionRequestDelegate?

    var state: State {
        didSet {
            let fromUser = userInitiated ? " (user initiated)" : ""
            log.info("Sysext request to \(action.rawValue) \(type.rawValue) now \(state.rawValue)\(fromUser)", category: .sysex)
        }
    }
    let action: Action
    let type: SystemExtensionType
    let userInitiated: Bool
    let completion: Completion

    required init(action: Action, type: SystemExtensionType, userInitiated: Bool, completion: @escaping Completion) {
        self.state = .outstanding
        self.action = action
        self.type = type
        self.userInitiated = userInitiated
        self.completion = completion
    }

    static func install(type: SystemExtensionType, userInitiated: Bool, completion: @escaping Completion) -> Self {
        Self(action: .install, type: type, userInitiated: userInitiated, completion: completion)
    }

    static func uninstall(type: SystemExtensionType, userInitiated: Bool, completion: @escaping Completion) -> Self {
        Self(action: .uninstall, type: type, userInitiated: userInitiated, completion: completion)
    }

    var asDaemonRequest: OSSystemExtensionRequest {
        let queue = SystemExtensionManagerImplementation.requestQueue
        let result: OSSystemExtensionRequest
        switch action {
        case .install:
            result = .activationRequest(forExtensionWithIdentifier: type.rawValue, queue: queue)
        case .uninstall:
            result = .deactivationRequest(forExtensionWithIdentifier: type.rawValue, queue: queue)
        }
        result.delegate = self
        return result
    }

    func needsUserApproval() {
        state = .userActionRequired
    }

    func actionForReplacing(existingExtension: SystemExtensionInfo, with: SystemExtensionInfo) -> OSSystemExtensionRequest.ReplacementAction {
        state = .replacing
        return .replace
    }

    func didFinish(withResult result: Result<OSSystemExtensionRequest.Result, Error>) {
        switch result {
        case .success:
            state = .succeeded
            delegate?.requestFinished(self)
        case .failure(let error):
            if let sysextError = error as? OSSystemExtensionError, sysextError.code == .requestSuperseded {
                state = .superseded
            } else {
                state = .failed
            }
            delegate?.requestFinished(self)

            guard state != .superseded else {
                return
            }
        }
        completion(result)
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        needsUserApproval()
    }

    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        guard let existingType = SystemExtensionType(rawValue: existing.bundleIdentifier) else {
            log.error("Unrecognized existing extension type \(existing.bundleIdentifier)", category: .sysex)
            didFinish(withResult: .failure(SystemExtensionError.unrecognizedType))
            return .cancel
        }

        guard let thisType = SystemExtensionType(rawValue: ext.bundleIdentifier) else {
            log.error("Unrecognized installing extension type \(existing.bundleIdentifier)", category: .sysex)
            didFinish(withResult: .failure(SystemExtensionError.unrecognizedType))
            return .cancel
        }

        guard existingType == thisType else {
            log.error("Asked to replace existing extension \(existingType.rawValue) with different type \(thisType.rawValue)")
            didFinish(withResult: .failure(SystemExtensionError.mismatchedType))
            return .cancel
        }

        let existingInfo = SystemExtensionInfo(type: existingType,
                                               bundleVersion: existing.bundleVersion,
                                               buildVersion: existing.bundleShortVersion)
        let thisInfo = SystemExtensionInfo(type: thisType,
                                           bundleVersion: ext.bundleVersion,
                                           buildVersion: ext.bundleShortVersion)

        return actionForReplacing(existingExtension: existingInfo, with: thisInfo)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        didFinish(withResult: .success(result))
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        didFinish(withResult: .failure(error))
    }
}

class SystemExtensionManagerImplementation: NSObject, SystemExtensionManager {
    typealias Factory = PropertiesManagerFactory & XPCConnectionsRepositoryFactory
    static let requestQueue = DispatchQueue(label: "ch.proton.sysex.requests")
    
    fileprivate let factory: Factory
    fileprivate lazy var propertiesManager: PropertiesManagerProtocol = self.factory.makePropertiesManager()
    fileprivate lazy var xpcConnectionsRepository: XPCConnectionsRepository = self.factory.makeXPCConnectionsRepository()
        
    private var activeRequests = Set<SystemExtensionRequest>()

    init(factory: Factory) {
        self.factory = factory
        super.init()
    }

    private func areAllExtensionsInstalled(completion: @escaping (Bool) -> Void) {
        extensionStatuses { statuses in
            completion(!statuses.contains { key, value in value != .ok })
        }
    }

    func extensionStatuses(resultHandler: @escaping ([SystemExtensionType: SystemExtensionStatus]) -> Void) {
        DispatchQueue.global().async {
            // Queue for writing into one dict from different threads. Prevents crashes in some cases.
            let statusQueue = DispatchQueue(label: "ch.proton.sysext.statuses")
            let dispatchGroup = DispatchGroup()
            var results = [SystemExtensionType: SystemExtensionStatus]()

            SystemExtensionType.allCases.forEach { type in
                dispatchGroup.enter()
                self.extensionStatus(forType: type, completion: { status in
                    statusQueue.sync {
                        results[type] = status
                        dispatchGroup.leave()
                    }
                })
            }

            dispatchGroup.wait()
            resultHandler(results)
        }
    }

    func extensionStatus(forType type: SystemExtensionType, completion: @escaping StatusCallback) {
        xpcConnectionsRepository.getXpcConnection(for: type.machServiceName).getVersion(completionHandler: { result in
            guard let data = result, let info = try? JSONDecoder().decode(ExtensionInfo.self, from: data) else {
                log.info("SysEx (\(type)) didn't return its version. Probably not yet installed.", category: .sysex)
                return completion(.notInstalled)
            }
            log.info("Got sysex (\(type)) version from extension: \(info)", category: .sysex)
            
            let appVersion = ExtensionInfo.current
            switch info.compare(to: appVersion) {
            case .orderedAscending:
                completion(.outdated)
                
            case .orderedDescending:
                log.info("SysEx version (\(info)) is higher than apps version (\(appVersion)", category: .sysex)
                completion(.outdated)
                
            case .orderedSame:
                completion(.ok)
            }
        })
    }

    func request(_ request: SystemExtensionRequest) {
        request.delegate = self
        log.info("Request extension \(request.action.rawValue) for \(request.type.rawValue)")

        // If we've already submitted a request for this type, call the completion early without
        // acting on the request.
        guard !(request.action == .install &&
            activeRequests.contains(where: { $0.type == request.type && $0.state == .userActionRequired }))
        else {
            request.state = .failed
            request.completion(.failure(SystemExtensionRequest.RequestAlreadyWaitingError()))
            return
        }

        activeRequests.insert(request)
        OSSystemExtensionManager.shared.submitRequest(request.asDaemonRequest)
    }
}

extension SystemExtensionManager {
    func uninstallAll(userInitiated: Bool, timeout: DispatchTime? = nil) -> DispatchTimeoutResult {
        if let impl = self as? SystemExtensionManagerImplementation {
            impl.propertiesManager.sysexSuccessWasShown = false
        }

        let group = DispatchGroup()

        SystemExtensionType.allCases.forEach { type in
            group.enter()
            self.request(.uninstall(type: type, userInitiated: userInitiated, completion: { _ in
                group.leave()
            }))
        }

        guard let timeout = timeout else {
            group.wait()
            return .success
        }

        return group.wait(timeout: timeout)
    }
}

extension SystemExtensionManagerImplementation: SystemExtensionRequestDelegate {
    func requestFinished(_ request: SystemExtensionRequest) {
        if request.action == .install {
            // Check install state regardless of whether or not there was an error
            areAllExtensionsInstalled { [weak self] extensionsInstalled in
                guard extensionsInstalled else { return }

                self?.propertiesManager.sysexSuccessWasShown = true

                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: SystemExtensionManagerNotification.allExtensionsInstalled, object: request)
                }
            }
        }
        activeRequests.remove(request)
    }
}
