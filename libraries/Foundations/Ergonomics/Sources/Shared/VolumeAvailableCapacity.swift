//
//  Created on 2026-06-03 by Pawel Jurczyk.
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

/// Dependency that reports the amount of disk space currently available.
/// Possible todo: create a publisher that would periodically check for the available
/// capacity and report every few seconds or few MB of change.
@DependencyClient
public struct VolumeAvailableCapacity: Sendable {
    /// Returns the volume's available capacity for important usage, in bytes.
    ///
    /// - Throws: `VolumeAvailableCapacityError`
    public var capacity: @Sendable () throws -> Int64
}

public enum VolumeAvailableCapacityError: Swift.Error {
    case failedRetrievingAvailableCapacity
}

extension VolumeAvailableCapacity: DependencyKey {
    public static let liveValue = VolumeAvailableCapacity(
        capacity: { () throws(VolumeAvailableCapacityError) in
            do {
                let resourceValues = try Bundle.main.bundleURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let capacity = resourceValues.volumeAvailableCapacityForImportantUsage {
                    return capacity
                } else {
                    throw VolumeAvailableCapacityError.failedRetrievingAvailableCapacity
                }
            } catch {
                throw VolumeAvailableCapacityError.failedRetrievingAvailableCapacity
            }
        }
    )

    public static var testValue: VolumeAvailableCapacity = value(with: 100)

    /// Builds a stub `VolumeAvailableCapacity` that always reports a fixed amount of free space.
    ///
    /// Use this in tests to drive code paths that branch on available storage (e.g. low-storage warnings)
    /// without touching the real filesystem.
    ///
    /// - Parameter capacity: The amount of available capacity to report, expressed in **MB**.
    /// - Returns: A `VolumeAvailableCapacity` whose `capacity()` closure returns the given value in bytes.
    public static func value(with capacity: Int) -> VolumeAvailableCapacity {
        .init {
            Int64(capacity) * 1 << 20
        }
    }
}

public extension DependencyValues {
    var volumeAvailableCapacity: VolumeAvailableCapacity {
        get { self[VolumeAvailableCapacity.self] }
        set { self[VolumeAvailableCapacity.self] = newValue }
    }
}
