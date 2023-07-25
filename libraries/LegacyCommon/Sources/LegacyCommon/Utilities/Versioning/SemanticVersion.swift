//
//  SemanticVersion.swift
//  vpncore - Created on 2021-01-05.
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

import Foundation

public struct SemanticVersion: CustomStringConvertible, Comparable {
    
    public let metadataComponents: [String]
    public let releaseComponents: [String]
    public let versionComponents: [Int]
    
    public var description: String
    
    public var major: Int {
        return versionComponents[0]
    }
    
    public var minor: Int {
        return versionComponents[1]
    }
    
    public var patch: Int {
        return versionComponents[2]
    }
    
    public init(_ version: String) throws {
        description = version
        metadataComponents = version.components(separatedBy: "+")
        releaseComponents = metadataComponents[0].components(separatedBy: "-")
        let versionStringComponents = releaseComponents[0].components(separatedBy: ".")
        guard versionStringComponents.count == 3 else {
            throw SemanticVersionError.wrongVersionComponentsCount
        }
        versionComponents = versionStringComponents.map { Int($0) ?? 0 }
    }
    
    enum SemanticVersionError: Error {
        case wrongVersionComponentsCount
    }
    
    // MARK: Comparison
    
    /// Compare two version strings
    /// Compares according to https://semver.org/#spec-item-11
    /// Important: not all comparison rules are imlemented. Only basis pre-release versions check is done.
    /// For the list of supported variants please check tests.
    public func compare(to other: SemanticVersion) -> ComparisonResult {
        for i in 0 ..< self.versionComponents.count {
            let thisVersion = self.versionComponents[i]
            let otherVersion = other.versionComponents[i]
            
            guard thisVersion != otherVersion else {
                continue
            }
            
            return thisVersion < otherVersion ? .orderedAscending : .orderedDescending
        }
        
        let preReleaseOrder = self.comparePreRelease(to: other)
        guard preReleaseOrder == .orderedSame else {
            return preReleaseOrder
        }
        
        return .orderedSame
    }
    
    private func comparePreRelease(to other: SemanticVersion) -> ComparisonResult {
        if self.releaseComponents.count > other.releaseComponents.count {
            return .orderedAscending
        } else if self.releaseComponents.count < other.releaseComponents.count {
            return .orderedDescending
        }
        
        guard self.releaseComponents.count > 1 else {
            return .orderedSame
        }
        
        for i in 1 ..< self.releaseComponents.count {
            let thisPreRelease = self.releaseComponents[i]
            let otherPreRelease = other.releaseComponents[i]
            
            guard thisPreRelease != otherPreRelease else {
                continue
            }
            
            return thisPreRelease.compare(otherPreRelease)
        }
        
        return .orderedSame
    }
    
    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.compare(to: rhs) == .orderedSame
    }
    
    public static func > (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.compare(to: rhs) == .orderedDescending
    }
    
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.compare(to: rhs) == .orderedAscending
    }
    
}
