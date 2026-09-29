//
//  Created on 17/08/2026 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
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

import Dependencies
import DependenciesMacros
import Foundation
#if canImport(WidgetKit)
    import WidgetKit
#endif
#if DEBUG
    import Domain
    import Sharing

    /// Debug-only instrumentation: how many timeline reloads we asked `WidgetKit` for, per day.
    public extension SharedKey where Self == JSONAppStorageKey<[DateComponents: Int]>.Default {
        static var reloadAllTimelinesCounter: Self {
            Self[.json("reloadAllTimelinesCounter", default: [:]), default: [:]]
        }
    }
#endif

// MARK: - Reason

public enum WidgetReloadReason: Sendable, Equatable {
    public enum ConnectionStateChange: Sendable, Equatable {
        case connected
        case connecting
        case disconnected
    }

    case connectionStateChanged(ConnectionStateChange)
    case recentsListChanged
    case defaultConnectionChanged
    case loggedInOrOut

    /// Only the large families render the recents list, so a recents change is worth a reload
    /// just when one of them is actually installed.
    var needsLargeWidget: Bool {
        self == .recentsListChanged
    }
}

// MARK: - WidgetKit access

@DependencyClient
public struct WidgetCenterClient: Sendable {
    /// Whether a widget large enough to render the recents list is installed.
    ///
    /// Conservatively `true` before iOS 18 / macOS 15, where the installed configurations can't
    /// be queried.
    public var hasLargeWidgetInstalled: @Sendable () async -> Bool = { true }
    /// Asks `WidgetKit` to rebuild the timelines of every installed widget.
    public var reloadAllTimelines: @Sendable () -> Void
}

extension WidgetCenterClient: DependencyKey {
    public static let liveValue = WidgetCenterClient(
        hasLargeWidgetInstalled: {
            #if canImport(WidgetKit)
                guard #available(iOS 18.0, macOS 15.0, *) else { return true }
                let configurations = await (try? WidgetCenter.shared.currentConfigurations()) ?? []
                return configurations.contains {
                    [.systemLarge, .systemExtraLarge].contains($0.family)
                }
            #else
                return false
            #endif
        },
        reloadAllTimelines: {
            #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    )

    public static let testValue = WidgetCenterClient()
}

public extension DependencyValues {
    var widgetCenter: WidgetCenterClient {
        get { self[WidgetCenterClient.self] }
        set { self[WidgetCenterClient.self] = newValue }
    }
}

// MARK: - Reload

@DependencyClient
public struct WidgetReload: Sendable {
    public var reloadAllTimelines: @Sendable (_ reason: WidgetReloadReason) -> Void
}

extension WidgetReload: DependencyKey {
    public static let liveValue: WidgetReload = {
        #if canImport(WidgetKit)
            let debouncer = Debouncer()
            return WidgetReload(reloadAllTimelines: { reason in
                Task {
                    await debouncer.reload(reason)
                }
            })
        #else
            // No `WidgetKit`, nothing to reload.
            return WidgetReload(reloadAllTimelines: { _ in })
        #endif
    }()

    public static let testValue = WidgetReload(reloadAllTimelines: { _ in })

    /// Collapses bursts of reload requests into a single `WidgetKit` reload, and drops the
    /// requests that wouldn't change anything the user can see.
    actor Debouncer {
        private static let debounceDuration = Duration.seconds(0.5)

        @Dependency(\.widgetCenter) private var widgetCenter
        @Dependency(\.continuousClock) private var clock

        private var pending: Task<Void, Never>?
        private var lastConnectionReloadReason: WidgetReloadReason.ConnectionStateChange?

        func reload(_ reason: WidgetReloadReason) async {
            if reason.needsLargeWidget {
                guard await widgetCenter.hasLargeWidgetInstalled() else { return }
            }
            if case let .connectionStateChanged(change) = reason {
                guard lastConnectionReloadReason != change else { return }
                lastConnectionReloadReason = change
            }
            pending?.cancel()
            pending = Task { [clock, widgetCenter] in
                try? await clock.sleep(for: Self.debounceDuration)
                guard !Task.isCancelled else { return }
                #if DEBUG
                    incrementReloadTimelinesCounter()
                #endif
                widgetCenter.reloadAllTimelines()
            }
        }
    }
}

#if DEBUG
    private func incrementReloadTimelinesCounter() {
        @Shared(.reloadAllTimelinesCounter) var reloadAllTimelinesCounter
        let calendarDate = Calendar.current.dateComponents([.day, .year, .month], from: .now)
        $reloadAllTimelinesCounter.withLock {
            $0[calendarDate] = ($0[calendarDate] ?? 0) + 1
        }
    }
#endif

public extension DependencyValues {
    /// Reloads widget timelines, debouncing repeated reloads.
    var widgetReload: WidgetReload {
        get { self[WidgetReload.self] }
        set { self[WidgetReload.self] = newValue }
    }
}
