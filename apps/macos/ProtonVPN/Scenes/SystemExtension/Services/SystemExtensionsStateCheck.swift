//
//  SystemExtensionStateCheck.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav Oo on 2021-08-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore

protocol SystemExtensionsStateCheckFactory {
    func makeSystemExtensionsStateCheck() -> SystemExtensionsStateCheck
}

extension DependencyContainer: SystemExtensionsStateCheckFactory {
    func makeSystemExtensionsStateCheck() -> SystemExtensionsStateCheck {
        return SystemExtensionsStateCheck(systemExtensionManager: makeSystemExtensionManager(), alertService: makeCoreAlertService(), propertiesManager: makePropertiesManager())
    }
}

class SystemExtensionsStateCheck {
    
    enum SuccessResultType {
        case nothing
        case installed // At least one sysex had to be installed
        case updated   // At least one sysex had to be updated, and NONE had to be installed
    }

    public struct UserCancelledInstall: Error, CustomStringConvertible {
        public let description = "The install was cancelled by the user."
    }
    
    private let systemExtensionManager: SystemExtensionManager
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    
    init(systemExtensionManager: SystemExtensionManager, alertService: CoreAlertService, propertiesManager: PropertiesManagerProtocol) {
        log.debug("SystemExtensionsStateCheck init", category: .sysex)

        self.systemExtensionManager = systemExtensionManager
        self.alertService = alertService
        self.propertiesManager = propertiesManager
    }

    deinit {
        log.debug("SystemExtensionsStateCheck deinit", category: .sysex)
    }

    // swiftlint:disable function_body_length
    func startCheckAndInstallIfNeeded(resultHandler: @escaping (Result<SuccessResultType, Error>) -> Void) {
        log.debug("Checking status of system extensions...", category: .sysex)

        fetchExtensionStatuses { statuses in
            var updateWasNeeded = false
            var installNeeded = [SystemExtensionType]()
            statuses.forEach { type, status in
                switch status {
                case .notInstalled:
                    log.info("SysEx \(type) is not installed", category: .sysex)
                    installNeeded.append(type)
                    
                case .outdated:
                    log.info("SysEx \(type) is outdated. Requesting install update.", category: .sysex)
                    updateWasNeeded = true
                    self.systemExtensionManager.requestExtensionInstall(forType: type, completion: { _ in })
                    
                case .ok:
                    log.info("SysEx \(type) is up to date", category: .sysex)
                }
            }
            
            guard !installNeeded.isEmpty else {
                log.debug("No initial install needed, bailing.", category: .sysex)
                resultHandler(.success(updateWasNeeded ? .updated : .nothing))
                return
            }
            
            guard !self.propertiesManager.sysexSuccessWasShown else {
                log.debug("Already showed Sysex success, bailing.", category: .sysex)

                return // Dirty workaround for a problem where after restart macos doesn't want to give us XPC connection on the first try and app thinks sysex is not yet installed.
            }
            
            self.alertService.push(alert: SystemExtensionTourAlert(extensionsCount: installNeeded.count, isTimeToClose: { [weak self] completion in
                self?.areAllExtensionsInstalled(completion: completion)
            }, continueHandler: {
                let dispatchGroup = DispatchGroup()
                var errors = [Error]()
                
                installNeeded.forEach { type in
                    dispatchGroup.enter()
                    log.debug("Requesting sysex install for \(type.rawValue)", category: .sysex)

                    self.systemExtensionManager.requestExtensionInstall(forType: type, completion: { result in
                        switch result {
                        case .success():
                            break
                            
                        case .failure(let error):
                            errors.append(error)
                        }
                        dispatchGroup.leave()
                    })
                }
                
                dispatchGroup.notify(queue: DispatchQueue.global(qos: .background)) {
                    guard errors.isEmpty else {
                        log.debug("Encountered errors in sysex install: \(String(describing: errors))", category: .sysex)

                        self.alertService.push(alert: SysexInstallingErrorAlert())
                        resultHandler(.failure(errors.first!))
                        return
                    }
                    resultHandler(.success(.installed))
                }
                
            }, cancelHandler: {
                log.debug("User cancelled system extension install", category: .sysex)
                resultHandler(.failure(UserCancelledInstall()))
            }))
        }
    }
    
    // Queue for writing into one array from different threads. Prevents crashes in some cases.
    private let queue = DispatchQueue(label: "ExtensionsStatusesQueue")
    
    private func fetchExtensionStatuses(resultHandler: @escaping ([SystemExtensionType: SystemExtensionStatus]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results = [SystemExtensionType: SystemExtensionStatus]()
        let extensions = SystemExtensionType.allCases
        extensions.forEach { type in
            dispatchGroup.enter()
            systemExtensionManager.extenstionStatus(forType: type, completion: { status in
                self.queue.async {
                    results[type] = status
                    dispatchGroup.leave()
                }
            })
        }
        dispatchGroup.notify(queue: DispatchQueue.global(qos: .background)) {
            resultHandler(results)
        }
    }
    
    private func areAllExtensionsInstalled(completion: @escaping (Bool) -> Void) {
        fetchExtensionStatuses { statuses in
            completion(!statuses.contains { key, value in value != .ok })
        }
    }
    
}
