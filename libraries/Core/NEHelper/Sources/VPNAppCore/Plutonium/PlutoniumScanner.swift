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
    import CombineSchedulers
    import ConcurrencyExtras
    import Dependencies
    import Foundation
    import Sharing
    import SwiftNavigation

    // TODO: refactor this VPNAPPL-3586
    public final actor PlutoniumScanner {
        public static let shared = PlutoniumScanner()

        @Shared(.childBundles) var childBundles: [String: ChildBundle]

        private static let scanInterval = TimeInterval.days(1)

        private var cancellables: Set<AnyCancellable> = []

        /// The most recently requested scan. Captured synchronously when a list
        /// change is observed so that `waitForScanToComplete()` always awaits the
        /// scan that the latest change triggered, rather than racing its creation.
        private let currentScan = LockIsolated<Task<Void, Never>?>(nil)

        private let debounceAmount: DispatchQueue.SchedulerTimeType.Stride
        private let scheduler: AnySchedulerOf<DispatchQueue>

        init(
            debounce: Int = 1,
            scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue(label: "ch.proton.mac.plutonium_scanner").eraseToAnyScheduler()
        ) {
            self.debounceAmount = .seconds(debounce)
            self.scheduler = scheduler
        }

        public func startObservation() {
            cancellables.removeAll()

            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            Publishers.Merge(
                $exclusionActivated.apps.publisher,
                $inclusionActivated.apps.publisher
            )
            .debounce(for: debounceAmount, scheduler: scheduler)
            .filter { !$0.isEmpty } // an empty array is emitted when the reader tears down; ignore it
            .sink { [weak self] apps in
                self?.scheduleScan(apps)
            }.store(in: &cancellables)
        }

        /// Enqueues a scan for `apps`, superseding any in-flight scan. Runs
        /// synchronously on the subscription's thread so the resulting task is
        /// visible to `waitForScanToComplete()` the moment the change is observed.
        private nonisolated func scheduleScan(_ apps: [PlutoniumApp]) {
            currentScan.withValue { current in
                let previous = current
                current = Task { [weak self] in
                    previous?.cancel() // don't start more operations
                    _ = await previous?.value // but finish the ones that are started
                    await self?.scan(apps)
                }
            }
        }

        public func waitForScanToComplete() async {
            await currentScan.value?.value
        }

        private func shouldScan(_ app: PlutoniumApp) -> Bool {
            let child = childBundles[app.bundleIdentifier]
            if let lastTimeChecked = child?.lastTimeChecked {
                return -lastTimeChecked.timeIntervalSinceNow > Self.scanInterval
            } else {
                return true
            }
        }

        private func enumerationOperation(_ app: PlutoniumApp) -> () async throws -> (String, ChildBundle) {
            {
                try Task.checkCancellation()
                @Dependency(\.appsProvider) var appsProvider
                let plugins = appsProvider.enumerateChildApplications(app)
                let ids = plugins.map(\.bundleIdentifier)
                return (app.bundleIdentifier, ChildBundle(bundleIdentifiers: ids, lastTimeChecked: .now))
            }
        }

        private func collect(from group: ThrowingTaskGroup<(String, ChildBundle), any Error>) async -> [(String, ChildBundle)] {
            var values: [(String, ChildBundle)] = []
            do {
                for try await value in group {
                    values.append(value)
                    try Task.checkCancellation()
                }
            } catch {
                return values
            }
            return values
        }

        private func scan(_ apps: [PlutoniumApp]) async {
            await Task.yield() // allow time for childBundles to update from the last scan
            let operations = apps
                .uniques(by: \.bundleIdentifier)
                .filter(shouldScan)
                .map(enumerationOperation)
            let collected = await withThrowingTaskGroup(of: (String, ChildBundle).self) { group in
                operations
                    .forEach { group.addTask(operation: $0) }
                return await collect(from: group)
            }
            $childBundles.withLock {
                $0.merge(collected) { _, new in
                    new
                }
            }
        }
    }
#endif
