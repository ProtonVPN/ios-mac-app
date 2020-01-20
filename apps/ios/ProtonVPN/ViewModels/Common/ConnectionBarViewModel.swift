//
//  ConnectionBarViewModel.swift
//  ProtonVPN - Created on 01.07.19.
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
import UIKit
import vpncore

protocol ConnectionBarViewModelDelegate: class {
    func timeString() -> String
}

class ConnectionBarViewModel {
    
    private let connectionStatusService: ConnectionStatusService
    private let appStateManager: AppStateManager
    
    private var timer = Timer()
    
    var setConnecting: (() -> Void)?
    var setConnected: (() -> Void)?
    var updateConnected: (() -> Void)?
    var setDisconnected: (() -> Void)?
    
    var statusViewController: StatusViewController? {
        return connectionStatusService.makeStatusViewController(delegate: self)
    }
    
    init(connectionStatusService: ConnectionStatusService, appStateManager: AppStateManager) {
        self.connectionStatusService = connectionStatusService
        self.appStateManager = appStateManager
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: appStateManager.stateChange, object: nil)
        
        self.updateState()
    }
    
    @objc func updateState() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            switch self.appStateManager.state {
            case .connected:
                self.setConnected?()
                if !self.timer.isValid {
                    self.runTimer()
                }
            case .preparingConnection, .connecting:
                self.timer.invalidate()
                self.setConnecting?()
            default:
                self.timer.invalidate()
                self.setDisconnected?()
            }
        }
    }
    
    private func runTimer() {
        timer = Timer(fireAt: Date(), interval: 1, target: self, selector: (#selector(self.timerFired)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
    }

    @objc private func timerFired() {
        DispatchQueue.main.async { [weak self] in
            self?.updateConnected?()
        }
    }
}

extension ConnectionBarViewModel: ConnectionBarViewModelDelegate {
    
    func timeString() -> String {
        let time: TimeInterval
        if case AppState.connected = appStateManager.state {
            let connectedDate = appStateManager.connectedDate() ?? Date()
            time = Date().timeIntervalSince(connectedDate)
        } else {
            time = 0
        }
        
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}
