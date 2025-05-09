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

        let thisBuildComponents = self.build.split(separator: ".")
        let otherBuildComponents = other.build.split(separator: ".")

        guard thisBuildComponents.count == otherBuildComponents.count else {
            return thisBuildComponents.count < otherBuildComponents.count ? .orderedAscending : .orderedDescending
        }

        for (thisComponent, otherComponent) in zip(thisBuildComponents, otherBuildComponents) {
            guard let thisInt = Int(String(thisComponent)), let otherInt = Int(String(otherComponent)) else {
                return .orderedAscending
            }

            guard thisInt != otherInt else { continue }
            return thisInt < otherInt ? .orderedAscending : .orderedDescending
        }

        return .orderedSame
    }
}
