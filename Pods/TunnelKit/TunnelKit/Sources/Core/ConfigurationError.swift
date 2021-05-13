//
//  ConfigurationError.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 4/3/19.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

/// Error raised by the configuration parser, with details about the line that triggered it.
public enum ConfigurationError: Error {
    
    /// Option syntax is incorrect.
    case malformed(option: String)
    
    /// A required option is missing.
    case missingConfiguration(option: String)
    
    /// An option is unsupported.
    case unsupportedConfiguration(option: String)
    
    /// Passphrase required to decrypt private keys.
    case encryptionPassphrase
    
    /// Encryption passphrase is incorrect or key is corrupt.
    case unableToDecrypt(error: Error)
}
