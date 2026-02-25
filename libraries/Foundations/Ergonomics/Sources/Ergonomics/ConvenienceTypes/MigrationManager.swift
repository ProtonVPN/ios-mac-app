//
//  MigrationManager.swift
//  vpncore - Created on 23/07/2020.
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

import Dependencies
import Foundation
import Sharing
import Version

/// The MigrationBlock contains the previous version of the App from which we updated, and an async action block.
public typealias MigrationBlock = @Sendable (_ version: Version) async throws -> Void

public protocol MigrationManager: Sendable {
    func checking(_ version: Version?, with block: @escaping MigrationBlock) -> Self
    func migrate() async throws(MigrationError)
}

public extension Version {
    static func platform(
        iOS: Self? = nil,
        macOS: Self? = nil,
        tvOS: Self? = nil
    ) -> Self? {
        #if os(iOS)
            return iOS
        #elseif os(macOS)
            return macOS
        #elseif os(tvOS)
            return tvOS
        #endif
    }
}

public struct MigrationError: Error, CustomStringConvertible {
    public let checkedVersion: Version
    public let resultingError: Error

    public var description: String {
        "Failed to run migration step for version \(checkedVersion): \(String(describing: resultingError))"
    }
}

public struct MigrationManagerImplementation: MigrationManager {
    private let finalVersion: Version

    @Shared(.lastAppVersion) private var lastAppVersion
    private let migrationBlocks: [(Version?, MigrationBlock)]

    // MARK: - MigrationManagerProtocol

    /// Create an empty migration manager according to the last app version specified in user defaults.
    ///
    /// Adding steps is done through the ``checking(version:with:)`` function, which returns a modified instance
    /// containing the new migration step. Once all steps are added, you can call ``migrate()`` on the final result.
    public init(finalVersion: Version? = nil) {
        @Shared(.lastAppVersion) var lastAppVersion

        // The current version of the app
        var finalVersion = finalVersion ?? Bundle.main.buildVersion

        if Version(lastAppVersion) == nil {
            assertionFailure("Bad lastAppVersion, skipping migration")
            finalVersion = Version(0, 0, 0)
        }

        self = .init(finalVersion: finalVersion)
    }

    private init(finalVersion: Version, migrationBlocks: [(Version?, MigrationBlock)] = []) {
        self.finalVersion = finalVersion
        self.migrationBlocks = migrationBlocks
    }

    /// Add a migration step where the version specified has to be GREATER than the previous version in order to be executed
    public func checking(_ version: Version?, with block: @escaping MigrationBlock) -> Self {
        Self(finalVersion: finalVersion, migrationBlocks: migrationBlocks.appending((version, block)))
    }

    /// Perform all the checks in the migration process, aborting if an error is thrown.
    public func migrate() async throws(MigrationError) {
        guard let previous = Version(lastAppVersion) else {
            assertionFailure("lastAppVersion seems to be corrupted, stopping migration")
            return
        }

        for (version, block) in migrationBlocks {
            guard let version else { continue }
            guard previous.migrationCompare(to: version) == .orderedAscending else {
                // Don't perform the migration if the last app version
                // is greater than or equal to the version specified in the migration.
                // e.g. we've already performed this migration before
                continue
            }
            if finalVersion.migrationCompare(to: version) == .orderedAscending {
                // Don't perform the migration if the current app version is earlier than
                // the version specified in the migration
                continue
            }

            do {
                try await block(previous)
            } catch {
                throw MigrationError(checkedVersion: version, resultingError: error)
            }

            $lastAppVersion.withLock { $0 = version.description }
        }
        $lastAppVersion.withLock { $0 = finalVersion.description }
    }
}

public extension SharedKey where Self == AppStorageKey<String>.Default {
    static var lastAppVersion: Self {
        Self[.appStorage("LastAppVersion"), default: "0.0.0"]
    }
}

extension Version: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        guard let version = Version(value) else {
            preconditionFailure("Invalid version used as literal: \(value)")
        }
        self = version
    }
}

private extension Version {
    /// Compare versions for purposes of migration.
    ///
    /// According to the semantic version specification, build metadata identifiers can't be used for comparison.
    /// We employ a little hack here to address the situation where two apps with the same short version, e.g., two beta
    /// builds with the same short version number, still might need to perform a migration step.
    ///
    /// If the migration manager notices that the short version for a migration step is equal to the current short
    /// version, and that migration step includes a build number, it will also perform that migration step according
    /// to the precedence of the build numbers.
    ///
    /// ```swift
    /// // Examples
    /// "1.2.3+12345.234".migrationCompare(to: "1.2.3+12344.212") == .orderedDescending
    /// "1.2.3+12345.234".migrationCompare(to: "1.2.3") == .orderedSame
    /// "1.2.3+12345.234".migrationCompare(to: "1.2.4+12344.233") == .orderedAscending
    /// ```
    func migrationCompare(to other: Self) -> ComparisonResult {
        guard !buildMetadataIdentifiers.isEmpty, !other.buildMetadataIdentifiers.isEmpty, self == other else {
            return self < other ? .orderedAscending : .orderedDescending
        }

        guard let thisBuild = Version(tolerant: buildMetadataIdentifiers.joined(separator: ".")),
              let otherBuild = Version(tolerant: buildMetadataIdentifiers.joined(separator: ".")) else {
            return .orderedSame
        }

        return thisBuild < otherBuild ? .orderedAscending : .orderedDescending
    }
}

private extension Bundle {
    var buildVersion: Version {
        let bundleVersion = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let buildNumber = infoDictionary?["CFBundleVersion"] as? String ?? "0.0"
        return Version("\(bundleVersion)+\(buildNumber)")!
    }
}

extension MigrationManagerImplementation: TestDependencyKey {
    public static let testValue: MigrationManager = { fatalError("MigrationManager not defined") }()
}

public extension DependencyValues {
    var migrationManager: MigrationManager {
        get { self[MigrationManagerImplementation.self] }
        set { self[MigrationManagerImplementation.self] = newValue }
    }
}
