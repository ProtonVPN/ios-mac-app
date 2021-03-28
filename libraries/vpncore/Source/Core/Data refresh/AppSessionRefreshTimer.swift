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
    
    public typealias Factory = AppSessionRefresherFactory
    private let factory: Factory
    
    private var timerFullRefresh: Timer?
    private var timerLoadsRefresh: Timer?
    
    public typealias RefreshCheckerCallback = () -> Bool
    private let canRefreshFull: RefreshCheckerCallback
    private let canRefreshLoads: RefreshCheckerCallback
    
    private var appSessionRefresher: AppSessionRefresher {
        return factory.makeAppSessionRefresher() // Do not retain it
    }
    
    public init(factory: Factory, fullRefresh: TimeInterval, serverLoadsRefresh: TimeInterval, canRefreshFull: @escaping RefreshCheckerCallback = { return true }, canRefreshLoads: @escaping RefreshCheckerCallback = { return true }) {
        self.factory = factory
        self.fullServerRefreshTimeout = fullRefresh
        self.serverLoadsRefreshTimeout = serverLoadsRefresh
        self.canRefreshFull = canRefreshFull
        self.canRefreshLoads = canRefreshLoads
    }
    
    public func start(now: Bool = false) {
        if timerFullRefresh == nil || !timerFullRefresh!.isValid {
            PMLog.D("Data refresh timer started (\(fullServerRefreshTimeout))", level: .trace)
            timerFullRefresh = Timer.scheduledTimer(timeInterval: fullServerRefreshTimeout, target: self, selector: #selector(refreshFull), userInfo: nil, repeats: true)
        }
        if timerLoadsRefresh == nil || !timerLoadsRefresh!.isValid {
            PMLog.D("Server loads refresh timer started (\(serverLoadsRefreshTimeout))", level: .trace)
            timerLoadsRefresh = Timer.scheduledTimer(timeInterval: serverLoadsRefreshTimeout, target: self, selector: #selector(refreshLoads), userInfo: nil, repeats: true)
        }
        if now {
            if appSessionRefresher.lastDataRefresh == nil || appSessionRefresher.lastDataRefresh!.addingTimeInterval(fullServerRefreshTimeout) < Date() {
                refreshFull()
            } else if appSessionRefresher.lastServerLoadsRefresh == nil || appSessionRefresher.lastServerLoadsRefresh!.addingTimeInterval(serverLoadsRefreshTimeout) < Date() {
                refreshLoads()
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
        guard canRefreshLoads() else {
            return }
        appSessionRefresher.refreshServerLoads()
    }
}
