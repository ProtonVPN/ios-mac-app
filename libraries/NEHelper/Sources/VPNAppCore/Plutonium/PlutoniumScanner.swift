//
//  Created on 2025-07-23 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

// singleton
// when created, open plutonium configuration AND for each app present discover all child bundles, update if changed
// scan once a day at most or when a new app is added?

import Combine
import Foundation
import Sharing

import CombineSchedulers
import SwiftNavigation

public class PlutoniumScanner {
    public static let shared: PlutoniumScanner = .init()

    @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated
    @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

    @Shared(.childBundles) static var childBundles: [String: ChildBundle]

    let scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue(label: #file, qos: .utility).eraseToAnyScheduler()

    var cancellables: Set<AnyCancellable> = []

    var task: Task<Void, any Error>?

    init() {
        Publishers.MergeMany(
            $exclusionActivated.apps.publisher,
            $inclusionActivated.apps.publisher
        )
        .debounce(for: .seconds(0.5), scheduler: scheduler)
        .sink { [weak self] apps in
            self?.startScanning(apps)
        }.store(in: &cancellables)
    }

    private func startScanning(_ apps: [PlutoniumApp]) {
        task?.cancel()
        task = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for app in apps {
                    let childBundle = Self.childBundles[app.bundleIdentifier]
                    let shouldCheckAgain = if let lastTimeChecked = childBundle?.lastTimeChecked {
                        -lastTimeChecked.timeIntervalSinceNow > TimeInterval.days(1)
                    } else {
                        true
                    }
                    guard shouldCheckAgain else {
                        continue
                    }

                    group.addTask(priority: .background) {
                        try Task.checkCancellation()
                        let plugins = FileManager.default.enumerateChildApplications(for: app)
                        let ids = plugins.map(\.bundleIdentifier)
                        Self.$childBundles.withLock {
                            $0[app.bundleIdentifier] = .init(bundleIdentifiers: ids, lastTimeChecked: .now)
                        }
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}
