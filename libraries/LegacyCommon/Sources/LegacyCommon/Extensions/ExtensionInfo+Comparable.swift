//
//  Created on 2022-07-27.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

extension ExtensionInfo: Equatable, Comparable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.compare(to: rhs) == .orderedSame
    }

    public static func > (lhs: Self, rhs: Self) -> Bool {
        return lhs.compare(to: rhs) == .orderedDescending
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.compare(to: rhs) == .orderedAscending
    }

    public func compare(to other: Self) -> ComparisonResult {
        guard let thisVersion = try? SemanticVersion(version) else {
            return .orderedAscending
        }

        guard let otherVersion = try? SemanticVersion(other.version) else {
            return .orderedDescending
        }

        let versionComparison = thisVersion.compare(to: otherVersion)
        guard versionComparison == .orderedSame else {
            return versionComparison
        }

        // Versions are the same, lets check build numbers
        guard let thisBuild = Int(self.build) else {
            return .orderedAscending
        }

        guard let otherBuild = Int(other.build) else {
            return .orderedDescending
        }

        guard thisBuild != otherBuild else {
            return .orderedSame
        }

        return thisBuild < otherBuild ? .orderedAscending : .orderedDescending
    }
}
