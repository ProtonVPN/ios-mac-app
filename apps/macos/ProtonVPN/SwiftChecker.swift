//
//  Swift5Checker.swift
//  ProtonVPN - Created on 2020-11-27.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation

/// Check if Swift is available on the system
public protocol SwiftChecker {
    func isSwiftAvailable() -> Bool
}

/// Checks swift5 path to determine if it is installed.
/// Used on older systems where swift5 is not installed by default.
public class SwiftCheckerImplementation: SwiftChecker {
    
    private let swiftPath = "/usr/lib/swift"
    private let fileManager = FileManager.default
    
    public func isSwiftAvailable() -> Bool {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: swiftPath, isDirectory: &isDir) {
            return isDir.boolValue
        } else {
            return false
        }
    }
    
}
