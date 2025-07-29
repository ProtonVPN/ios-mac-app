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

#if canImport(AppKit)

    import Combine
    import Foundation
    import Sharing

    import CombineSchedulers
    import SwiftNavigation

    public final class PlutoniumScanner {
        public static let shared: PlutoniumScanner = .init()

        @SharedReader(.exclusionActivated) private var exclusionActivated: PlutoniumActivated
        @SharedReader(.inclusionActivated) private var inclusionActivated: PlutoniumActivated

        @Shared(.childBundles) var childBundles: [String: ChildBundle]

        private static let scanInterval = TimeInterval.days(1)

        private var cancellables: Set<AnyCancellable> = []

        private var task: Task<Void, any Error>?

        var workGroup: ThrowingTaskGroup<(String, ChildBundle), any Error>?

        init(
            debounce: Int = 1,
            scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue(label: #file, qos: .utility).eraseToAnyScheduler()
        ) {
            let debounceAmount: DispatchQueue.SchedulerTimeType.Stride = .seconds(debounce)

            Publishers.CombineLatest(
                $exclusionActivated.apps.publisher,
                $inclusionActivated.apps.publisher
            )
            .debounce(for: debounceAmount, scheduler: scheduler)
            .map { $0.0 + $0.1 }
            .sink { [weak self] apps in
                self?.startScanning(apps)
            }.store(in: &cancellables)
        }

        public func waitForScanToComplete() async {
            try? await workGroup?.waitForAll()
            _ = await task?.result
        }

        private func shouldScan(child: ChildBundle?) -> Bool {
            if let lastTimeChecked = child?.lastTimeChecked {
                -lastTimeChecked.timeIntervalSinceNow > Self.scanInterval
            } else {
                true
            }
        }

        private func enumerationOperation(_ app: PlutoniumApp) -> () async throws -> (String, ChildBundle) {
            {
                try Task.checkCancellation()
                let plugins = FileManager.default.enumerateChildApplications(for: app)
                let ids = plugins.map(\.bundleIdentifier)
                return (app.bundleIdentifier, ChildBundle(bundleIdentifiers: ids, lastTimeChecked: .now))
            }
        }

        private func collect(from group: ThrowingTaskGroup<(String, ChildBundle), any Error>) async {
            var collected = [String: ChildBundle]()
            do {
                for try await value in group {
                    collected[value.0] = value.1
                }
                $childBundles.withLock {
                    $0.merge(collected) {
                        $1 // the new
                    }
                }
            } catch { // update anyway
                $childBundles.withLock {
                    $0.merge(collected) {
                        $1 // the new
                    }
                }
            }
        }

        private func startScanning(_ apps: [PlutoniumApp]) {
            @Shared(.childBundles) var childBundles: [String: ChildBundle]
            task?.cancel()
            task = Task {
                await Task.yield() // allow time for childBundles to update from the last scan
                await withThrowingTaskGroup(of: (String, ChildBundle).self) { group in
                    self.workGroup = group
                    apps
                        .uniques(by: \.bundleIdentifier)
                        .filter { shouldScan(child: childBundles[$0.bundleIdentifier]) }
                        .map(enumerationOperation)
                        .forEach { group.addTask(priority: .utility, operation: $0) }

                    await collect(from: group)
                }
            }
        }
    }
#endif
