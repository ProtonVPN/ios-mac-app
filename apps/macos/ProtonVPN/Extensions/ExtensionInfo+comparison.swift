//
//  ExtensionInfo+comparison.swift
//  macOS
//
//  Created by Jaroslav on 2021-07-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore

extension ExtensionInfo {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.compare(to: rhs) == .orderedSame
    }
    
    static func > (lhs: Self, rhs: Self) -> Bool {
        return lhs.compare(to: rhs) == .orderedDescending
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
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
