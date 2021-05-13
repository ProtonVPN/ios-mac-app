//
//  CompressionAlgorithm.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 3/19/19.
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
import __TunnelKitOpenVPN

extension OpenVPN {
    
    /// Defines the type of compression algorithm.
    public enum CompressionAlgorithm: Int, Codable, CustomStringConvertible {
        
        /// No compression.
        case disabled
        
        /// LZO compression.
        case LZO
        
        /// Any other compression algorithm (unsupported).
        case other
        
        var native: CompressionAlgorithmNative {
            guard let val = CompressionAlgorithmNative(rawValue: rawValue) else {
                fatalError("Unhandled CompressionAlgorithm bridging")
            }
            return val
        }
        
        // MARK: CustomStringConvertible
        
        /// :nodoc:
        public var description: String {
            switch self {
            case .disabled:
                return "disabled"
                
            case .LZO:
                return "lzo"
                
            case .other:
                return "other"
            }
        }
    }
}
