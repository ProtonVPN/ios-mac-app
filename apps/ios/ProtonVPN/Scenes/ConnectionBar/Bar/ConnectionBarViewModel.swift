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

class ConnectionBarViewModel {
    
    private let appStateManager: AppStateManager
    
    private var timer = Timer()
    private var connectedDate = Date()
    
    var setConnecting: (() -> Void)?
    var setConnected: (() -> Void)?
    var updateConnected: (() -> Void)?
    var setDisconnected: (() -> Void)?
    
    init(appStateManager: AppStateManager) {
        self.appStateManager = appStateManager
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: appStateManager.stateChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDisplayState), name: appStateManager.displayStateChange, object: nil)

        self.updateDisplayState()
        self.updateState()
    }

    @objc func updateDisplayState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            switch self.appStateManager.displayState {
            case .connected:
                self.setConnected?()
            case .preparingConnection, .connecting:
                self.setConnecting?()
            default:
                self.setDisconnected?()
            }
        }
    }
    
    @objc func updateState() {
        appStateManager.connectedDate { [weak self] (date) in
            self?.connectedDate = date ?? Date()
        }
        
        switch self.appStateManager.state {
        case .connected:
            if !self.timer.isValid {
                self.runTimer()
            }
        case .preparingConnection, .connecting:
            self.timer.invalidate()
        default:
            self.timer.invalidate()
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
    
    func timeString() -> String {
        let time: TimeInterval
        if case AppState.connected = appStateManager.state {
            time = Date().timeIntervalSince(connectedDate)
        } else {
            time = 0
        }
        
        return time.asString
    }
}
