//
//  AppSessionRefreshTimer.swift
//  vpncore - Created on 2020-09-01.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Clocks
import Dependencies
import Foundation
import Timer

public protocol AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer
}

public protocol AppSessionRefreshTimerDelegate: AnyObject {
    func shouldRefreshFull() -> Bool
    func shouldRefreshLoads() -> Bool
    func shouldRefreshAccount() -> Bool
    func shouldRefreshStreaming() -> Bool
    func shouldRefreshPartners() -> Bool
}

public extension AppSessionRefreshTimerDelegate {
    func shouldRefreshFull() -> Bool { true }
    func shouldRefreshLoads() -> Bool { true }
    func shouldRefreshAccount() -> Bool { true }
    func shouldRefreshStreaming() -> Bool { true }
    func shouldRefreshPartners() -> Bool { true }
}

public protocol AppSessionRefreshTimer {
    /// Start app session refresh timers
    ///
    /// Renamed from just start() to make it easier to search for usages in code.
    func startTimers()

    /// Stop app session refresh timers
    ///
    /// Renamed from just stop() to make it easier to search for usages in code.
    func stopTimers()
}

public class AppSessionRefreshTimerImplementation: AppSessionRefreshTimer {
    // swiftlint:disable:next large_tuple
    public typealias RefreshIntervals = (
        full: TimeInterval,
        loads: TimeInterval,
        account: TimeInterval,
        streaming: TimeInterval,
        partners: TimeInterval
    )

    private let refreshIntervals: RefreshIntervals

    public typealias Factory = AppSessionRefresherFactory
    private let factory: Factory

    @Dependency(\.continuousClock) var clock
    private var fullRefreshTask: Task<Void, Error>?
    private var loadsRefreshTask: Task<Void, Error>?
    private var accountRefreshTask: Task<Void, Error>?
    private var streamingRefreshTask: Task<Void, Error>?

    private var appSessionRefresher: AppSessionRefresher {
        factory.makeAppSessionRefresher() // Do not retain it
    }

    private weak var delegate: AppSessionRefreshTimerDelegate?

    public init(
        factory: Factory,
        refreshIntervals: RefreshIntervals,
        delegate: AppSessionRefreshTimerDelegate?
    ) {
        self.factory = factory
        self.refreshIntervals = refreshIntervals
        self.delegate = delegate
    }

    public func startTimers() {
        let refreshes = [
            (\AppSessionRefreshTimerImplementation.accountRefreshTask, refreshAccount, refreshIntervals.account),
            (\AppSessionRefreshTimerImplementation.fullRefreshTask, refreshFull, refreshIntervals.full),
            (\AppSessionRefreshTimerImplementation.loadsRefreshTask, refreshLoads, refreshIntervals.loads),
            (\AppSessionRefreshTimerImplementation.streamingRefreshTask, refreshStreaming, refreshIntervals.streaming),
        ]

        for (taskPath, timerFunction, refreshInterval) in refreshes {
            let task = self[keyPath: taskPath]

            guard task == nil else {
                continue
            }
            log.debug("Scheduling refresh timer", category: .app, metadata: ["task": "\(String(describing: timerFunction))", "interval": "\(refreshInterval)"])
            self[keyPath: taskPath] = Task {
                for await _ in clock.timer(interval: .seconds(refreshInterval)) {
                    log.debug("Refresh timer tick", category: .app, metadata: ["task": "\(String(describing: timerFunction))"])
                    await timerFunction()
                }
                log.debug("Refresh timer cancelled", category: .app, metadata: ["task": "\(String(describing: timerFunction))"])
            }
        }
    }

    public func stopTimers() {
        fullRefreshTask?.cancel()
        loadsRefreshTask?.cancel()
        accountRefreshTask?.cancel()
        streamingRefreshTask?.cancel()

        fullRefreshTask = nil
        loadsRefreshTask = nil
        accountRefreshTask = nil
        streamingRefreshTask = nil
    }

    private func refreshFull() async {
        guard let delegate, delegate.shouldRefreshFull() else { return }
        await appSessionRefresher.refreshData()
    }

    private func refreshLoads() async {
        guard let delegate, delegate.shouldRefreshLoads() else { return }
        await appSessionRefresher.refreshServerLoads()
    }

    private func refreshAccount() async {
        guard let delegate, delegate.shouldRefreshAccount() else { return }
        await appSessionRefresher.refreshAccount()
    }

    private func refreshStreaming() async {
        guard let delegate, delegate.shouldRefreshStreaming() else { return }
        await appSessionRefresher.refreshStreamingServices()
    }
}
