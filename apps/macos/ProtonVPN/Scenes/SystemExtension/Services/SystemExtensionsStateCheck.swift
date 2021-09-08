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
        return SystemExtensionsStateCheck(systemExtensionManager: makeSystemExtensionManager(), alertService: makeCoreAlertService())
    }
}

class SystemExtensionsStateCheck {
    
    enum SuccessResultType {
        case nothing
        case installed // At least one sysex had to be installed
        case updated   // At least one sysex had to be updated, and NONE had to be installed
    }
    
    private let systemExtensionManager: SystemExtensionManager
    private let alertService: CoreAlertService
    
    init(systemExtensionManager: SystemExtensionManager, alertService: CoreAlertService) {
        self.systemExtensionManager = systemExtensionManager
        self.alertService = alertService
    }
    
    func startCheckAndInstallIfNeeded(resultHandler: @escaping (Result<SuccessResultType, Error>) -> Void) {
        PMLog.D("Checking status of system extensions...")

        fetchExtensionStatuses { statuses in
            var updateWasNeeded = false
            var installNeeded = [SystemExtensionType]()
            statuses.forEach { type, status in
                switch status {
                case .notInstalled:
                    PMLog.D("SysEx \(type) is not installed")
                    installNeeded.append(type)
                    
                case .outdated:
                    PMLog.D("SysEx \(type) is outdated. Requesting install update.")
                    updateWasNeeded = true
                    self.systemExtensionManager.requestExtensionInstall(forType: type, completion: { _ in })
                    
                case .ok:
                    PMLog.D("SysEx \(type) is up to date")
                }
            }
            
            guard !installNeeded.isEmpty else {
                resultHandler(.success(updateWasNeeded ? .updated : .nothing))
                return
            }
            
            self.alertService.push(alert: SystemExtensionTourAlert(extensionsCount: installNeeded.count, isTimeToClose: { [weak self] completion in
                self?.areAllExtensionsInstalled(completion: completion)
                
            }, continueHandler: {
                let dispatchGroup = DispatchGroup()
                var errors = [Error]()
                
                installNeeded.forEach { type in
                    dispatchGroup.enter()
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
                        self.alertService.push(alert: SysexInstallingErrorAlert())
                        resultHandler(.failure(errors.first!))
                        return
                    }
                    resultHandler(.success(.installed))
                }
                
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
