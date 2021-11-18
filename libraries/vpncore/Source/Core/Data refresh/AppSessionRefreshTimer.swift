//
//  AppSessionRefreshTimer.swift
//  vpncore - Created on 2020-09-01.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public protocol AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer
}

public class AppSessionRefreshTimer {
    private let fullServerRefreshTimeout: TimeInterval // Default: 3 hours
    private let serverLoadsRefreshTimeout: TimeInterval // Default: 15 minutes
    private let accountRefreshTimeout: TimeInterval // Default: 3 minutes
    
    public typealias Factory = AppSessionRefresherFactory
    private let factory: Factory
    
    private var timerFullRefresh: Timer?
    private var timerLoadsRefresh: Timer?
    private var timerAccountRefresh: Timer?
    
    public typealias RefreshCheckerCallback = () -> Bool
    private let canRefreshFull: RefreshCheckerCallback
    private let canRefreshLoads: RefreshCheckerCallback
    private let canRefreshAccount: RefreshCheckerCallback
    
    private var appSessionRefresher: AppSessionRefresher {
        return factory.makeAppSessionRefresher() // Do not retain it
    }
    
    public init(factory: Factory, fullRefresh: TimeInterval, serverLoadsRefresh: TimeInterval, accountRefresh: TimeInterval,
                canRefreshFull: @escaping RefreshCheckerCallback = { return true },
                canRefreshLoads: @escaping RefreshCheckerCallback = { return true },
                canRefreshAccount: @escaping RefreshCheckerCallback = { return true }) {
        self.factory = factory
        self.fullServerRefreshTimeout = fullRefresh
        self.serverLoadsRefreshTimeout = serverLoadsRefresh
        self.accountRefreshTimeout = accountRefresh
        
        self.canRefreshFull = canRefreshFull
        self.canRefreshLoads = canRefreshLoads
        self.canRefreshAccount = canRefreshAccount
    }
    
    public func start(now: Bool = false) {
        if timerFullRefresh == nil || !timerFullRefresh!.isValid {
            log.debug("Data refresh timer started", category: .app, metadata: ["interval": "\(fullServerRefreshTimeout)"])
            timerFullRefresh = Timer.scheduledTimer(timeInterval: fullServerRefreshTimeout, target: self, selector: #selector(refreshFull), userInfo: nil, repeats: true)
        }
        if timerLoadsRefresh == nil || !timerLoadsRefresh!.isValid {
            log.debug("Server loads refresh timer started", category: .app, metadata: ["interval": "\(serverLoadsRefreshTimeout)"])
            timerLoadsRefresh = Timer.scheduledTimer(timeInterval: serverLoadsRefreshTimeout, target: self, selector: #selector(refreshLoads), userInfo: nil, repeats: true)
        }
        if timerAccountRefresh == nil || !timerAccountRefresh!.isValid {
            log.debug("Account refresh timer started", category: .app, metadata: ["interval": "\(accountRefreshTimeout)"])
            timerAccountRefresh = Timer.scheduledTimer(timeInterval: accountRefreshTimeout, target: self, selector: #selector(refreshAccount), userInfo: nil, repeats: true)
        }
        if now {
            if appSessionRefresher.lastDataRefresh == nil || appSessionRefresher.lastDataRefresh!.addingTimeInterval(fullServerRefreshTimeout) < Date() {
                refreshFull()
            } else if appSessionRefresher.lastServerLoadsRefresh == nil || appSessionRefresher.lastServerLoadsRefresh!.addingTimeInterval(serverLoadsRefreshTimeout) < Date() {
                refreshLoads()
            }
            
            if appSessionRefresher.lastAccountRefresh == nil || appSessionRefresher.lastAccountRefresh!.addingTimeInterval(accountRefreshTimeout) < Date() {
                refreshAccount()
            }
        }
    }
    
    public func stop() {
        if let timerFullRefresh = timerFullRefresh {
            timerFullRefresh.invalidate()
        }
        if let timerLoadsRefresh = timerLoadsRefresh {
            timerLoadsRefresh.invalidate()
        }
        timerFullRefresh = nil
        timerLoadsRefresh = nil
    }
    
    @objc private func refreshFull() {
        guard canRefreshFull() else { return }
        appSessionRefresher.refreshData()
    }
    
    @objc private func refreshLoads() {
        guard canRefreshLoads() else { return }
        appSessionRefresher.refreshServerLoads()
    }
    
    @objc private func refreshAccount() {
        guard canRefreshAccount() else { return }
        appSessionRefresher.refreshAccount()
    }
}
