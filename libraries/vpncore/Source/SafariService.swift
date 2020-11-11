//
//  SafariService.swift
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

#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

public protocol SafariServiceProtocol {
    func open(url: String)
}

public protocol SafariServiceFactory {
    func makeSafariService() -> SafariServiceProtocol
}

public class SafariService: SafariServiceProtocol {
    
    // Old
    public static func openLink(url: String) {
        guard let url = URL(string: url) else {
            return
        }
        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        #elseif canImport(Cocoa)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    // Use this one in new code
    public func open(url: String) {
        SafariService.openLink(url: url)
    }
    
    public init() {
    }
}
