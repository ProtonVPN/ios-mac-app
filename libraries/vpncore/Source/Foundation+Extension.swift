//
//  Foundation+Extension.swift
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

public func dispatch_after_delay(_ delay: TimeInterval, queue: DispatchQueue, block: @escaping () -> Void) {
    let time = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
    queue.asyncAfter(deadline: time, execute: block)
}

public func delay(_ delay: Double, closure:@escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: closure)
}

public func NSLocalizedString(_ key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

// MARK: - Internal
// Allows overwriting of values by clients using vpncore
internal func NSLocalizedString(_ key: String, comment: String = "") -> String {
    func enPathForBundle(_ bundle: Bundle) -> String? {
        return bundle.path(forResource: "en", ofType: "lproj")
    }
    
    // Look for string in client bundle
    var string = NSLocalizedString(key, bundle: Bundle.main, value: key, comment: comment)
    guard string == key else {
        return string
    }
    
    #if DEBUG
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        // Use client strings for tests
        return string
    }
    #endif
    
    let vpnCoreBundle = Bundle(path: Bundle(for: LocalizedString.self).path(forResource: "vpncore", ofType: "bundle")!)!
    
    // Look for string in vpncore
    string = NSLocalizedString(key, bundle: vpnCoreBundle, value: key, comment: comment)
    guard string == key else {
        return string
    }
    
    if let enClientPath = enPathForBundle(Bundle.main),
       let enClientBundle = Bundle(path: enClientPath) {
        // Use en translation from client if the preferred language is returning the key
        string = NSLocalizedString(key, bundle: enClientBundle, comment: comment)
    }
    
    guard string == key else {
        return string
    }
    
    guard let enCorePath = enPathForBundle(vpnCoreBundle),
          let enCoreBundle = Bundle(path: enCorePath) else {
        return key
    }
    
    // Use en translation from vpncore if the preferred language is returning the key
    return NSLocalizedString(key, bundle: enCoreBundle, comment: comment)
}
