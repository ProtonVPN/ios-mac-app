//
//  NSCoding+Extension.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public extension NSCoding {
    
    // Usage: Call for each class before any decoding has been done for the class
    //
    // Allows for previously encoded objects under the ProtonVPN module
    static func registerClassName(with moduleName: String) {
        let classNameComponents = NSStringFromClass(self).components(separatedBy: ".").dropFirst()
        let className = classNameComponents.joined(separator: ".")
        NSKeyedArchiver.setClassName("\(moduleName).\(className)", for: self)
        NSKeyedUnarchiver.setClass(self, forClassName: "\(moduleName).\(className)")
    }
}

// To be called in AppDelegate to preserve archived data
public func setUpNSCoding(withModuleName moduleName: String) {
    AuthCredentials.registerClassName(with: moduleName)
    Profile.registerClassName(with: moduleName)
    ServerIp.registerClassName(with: moduleName)
    ServerLocation.registerClassName(with: moduleName)
    ServerModel.registerClassName(with: moduleName)
    SessionModel.registerClassName(with: moduleName)
    VpnCredentials.registerClassName(with: moduleName)
}
