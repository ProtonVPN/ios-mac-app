//
//  UpdateFileSelector.swift
//  ProtonVPN - Created on 2021-01-18.
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
import vpncore

protocol UpdateFileSelector {
    var updateFileUrl: String { get }
}

protocol UpdateFileSelectorFactory {
    func makeUpdateFileSelector() -> UpdateFileSelector
}

public class UpdateFileSelectorImplementation: UpdateFileSelector {

    public typealias Factory = PropertiesManagerFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    public var forceNECapableOS: Bool? // `true` will force new file despite the OS version. `false` will force old file. `nil` - decide depending on OS.
    
    public init(_ factory: Factory) {
        self.factory = factory
    }
    
    var updateFileUrl: String {
        if propertiesManager.earlyAccess {
            return "https://protonvpn.com/download/macos-early-access-update\(updateFileVersion).xml"
        }
        return "https://protonvpn.com/download/macos-update\(updateFileVersion).xml"
    }
    
    private var updateFileVersion: String {
        if let force = forceNECapableOS {
            return force ? "3" : "2"
        }
        
        if #available(OSX 10.15, *) {
            return "3"
        }
        
        // macOS 10.14 and older
        return "2"
    }
}
