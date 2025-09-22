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
    import Dependencies
    import Foundation
    import Sharing

    import CombineSchedulers
    import SwiftNavigation

    public final actor PlutoniumScanner {
        public static let shared = PlutoniumScanner()

        @Shared(.childBundles) var childBundles: [String: ChildBundle]

        private static let scanInterval = TimeInterval.days(1)

        private var cancellables: Set<AnyCancellable> = []

        private var task: Task<Void, any Error>?
        private var continuation: AsyncStream<[PlutoniumApp]>.Continuation?

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
            self.continuation?.finish()

            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            let (asyncStream, continuation) = AsyncStream<[PlutoniumApp]>.makeStream()
            Publishers.Merge(
                $exclusionActivated.apps.publisher,
                $inclusionActivated.apps.publisher
            )
            .debounce(for: debounceAmount, scheduler: scheduler)
            .filter { !$0.isEmpty } // when we finish the stream, we get an empty array, which we can ignore
            .sink {
                continuation.yield($0)
            }.store(in: &cancellables)

            self.continuation = continuation

            Task {
                for await apps in asyncStream {
                    await startScanning(apps)
                }
            }
        }

        public func waitForScanToComplete() async {
            _ = await task?.result
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

        private func startScanning(_ apps: [PlutoniumApp]) async {
            task?.cancel() // don't start more operations
            _ = await task?.result // but finish the ones that are started
            task = Task {
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
    }
#endif
