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

    public final actor PlutoniumScanner {
        private static var task: Task<PlutoniumScanner, Never>?

        public static var shared: PlutoniumScanner {
            get async {
                if let task { return await task.value }
                task = Task { await PlutoniumScanner() }
                return await task!.value
            }
        }

        @Shared(.childBundles) var childBundles: [String: ChildBundle]

        private static let scanInterval = TimeInterval.days(1)

        private var cancellables: Set<AnyCancellable> = []

        private var task: Task<Void, any Error>?

        private let debounceAmount: DispatchQueue.SchedulerTimeType.Stride
        private let scheduler: AnySchedulerOf<DispatchQueue>

        init(
            debounce: Int = 1,
            scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue(label: "ch.proton.mac.plutonium_scanner").eraseToAnyScheduler()
        ) async {
            self.debounceAmount = .seconds(debounce)
            self.scheduler = scheduler
            startObservation()
        }

        private func startObservation() {
            cancellables.removeAll()

            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            let (asyncStream, continuation) = AsyncStream<[PlutoniumApp]>.makeStream()
            Publishers.Merge(
                $exclusionActivated.apps.publisher,
                $inclusionActivated.apps.publisher
            )
            .debounce(for: debounceAmount, scheduler: scheduler)
            .sink {
                continuation.yield($0)
            }.store(in: &cancellables)

            Task {
                for await apps in asyncStream {
                    startScanning(apps)
                }
            }
        }

        public func waitForScanToComplete() async {
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
            do {
                for try await value in group {
                    $childBundles.withLock {
                        $0[value.0] = value.1
                    }
                    try Task.checkCancellation()
                }
            } catch {}
        }

        private func startScanning(_ apps: [PlutoniumApp]) {
            task?.cancel()
            task = Task {
                @Shared(.childBundles) var childBundles: [String: ChildBundle]
                await Task.yield() // allow time for childBundles to update from the last scan
                await withThrowingTaskGroup(of: (String, ChildBundle).self) { group in
                    apps
                        .uniques(by: \.bundleIdentifier)
                        .filter { shouldScan(child: childBundles[$0.bundleIdentifier]) }
                        .map(enumerationOperation)
                        .forEach { group.addTask(operation: $0) }

                    await collect(from: group)
                }
            }
        }
    }
#endif
