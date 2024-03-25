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

import Ergonomics
import Foundation
import UIKit
import LegacyCommon

final class ConnectionBarViewModel {
    
    private let appStateManager: AppStateManager
    
    private var timer = Timer()
    private var connectedDate = Date()
    
    var onAppDisplayStateChanged: ((AppDisplayState) -> Void)?
    var updateConnected: (() -> Void)?
    
    init(appStateManager: AppStateManager) {
        self.appStateManager = appStateManager

        NotificationCenter.default.addObserver(forName: .AppStateManager.stateChange,
                                               object: nil,
                                               queue: nil,
                                               using: updateState)
        NotificationCenter.default.addObserver(forName: .AppStateManager.displayStateChange,
                                               object: nil,
                                               queue: nil,
                                               using: updateDisplayState)

        self.updateDisplayState(with: appStateManager.displayState)
        self.updateState(with: appStateManager.state)
    }

    /// Should only be called from the UI thread, since it accesses the `appStateManager` directly and
    /// does not get the state from a `displayStateChange` notification.
    func updateDisplayStateFromUIThread() {
        dispatchAssert(condition: .onQueue(.main))
        updateDisplayState(with: appStateManager.displayState)
    }

    private func updateDisplayState(_ notification: Notification) {
        guard let displayState = notification.object as? AppDisplayState else {
            return
        }

        updateDisplayState(with: displayState)
    }

    private func updateDisplayState(with displayState: AppDisplayState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }

            self.onAppDisplayStateChanged?(displayState)
        }
    }

    /// Should only be called from the UI thread, since it accesses the `appStateManager` directly and
    /// does not get the state from a `stateChange` notification.
    func updateStateFromUIThread() {
        dispatchAssert(condition: .onQueue(.main))
        updateState(with: appStateManager.state)
    }
    
    private func updateState(_ notification: Notification) {
        guard let state = notification.object as? AppState else {
            return
        }

        updateState(with: state)
    }

    private func updateState(with state: AppState) {
        Task {
            self.connectedDate = (await appStateManager.connectedDate()) ?? Date()
        }

        switch state {
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
        
        return time.asColonSeparatedString
    }
}
