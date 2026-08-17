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

    var shouldDebounce: Bool {
        switch self {
        case .connectionStateChanged:
            // don't reload if the last two reasons are the same connection state
            false
        default:
            true
        }
    }
}

@DependencyClient
public struct WidgetReload: Sendable {
    public var reloadAllTimelines: @Sendable (_ reason: WidgetReloadReason) -> Void
}

extension WidgetReload: DependencyKey {
    public static let liveValue: WidgetReload = {
        let debouncer = Debouncer()
        return WidgetReload(reloadAllTimelines: { reason in
            Task {
                await debouncer.reload(reason)
            }
        })
    }()

    public static let testValue = WidgetReload(reloadAllTimelines: { _ in })

    private actor Debouncer {
        private var lastReason: WidgetReloadReason?
        private var pending: Task<Void, Never>?

        func reload(_ reason: WidgetReloadReason) {
            pending?.cancel()
            if reason == lastReason {
                if reason.shouldDebounce {
                    pending = Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        guard !Task.isCancelled else { return }
                        Self.reloadNow()
                    }
                }
            } else {
                lastReason = reason
                pending = nil
                Self.reloadNow()
            }
        }

        private static func reloadNow() {
            #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}

public extension DependencyValues {
    /// Reloads widget timelines, debouncing repeated reloads that share the same ``WidgetReloadReason``.
    var widgetReload: WidgetReload {
        get { self[WidgetReload.self] }
        set { self[WidgetReload.self] = newValue }
    }
}
