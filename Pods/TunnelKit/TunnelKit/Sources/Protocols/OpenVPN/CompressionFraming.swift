//
//  CompressionFraming.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 8/30/18.
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

    /// Defines the type of compression framing.
    public enum CompressionFraming: Int, Codable, CustomStringConvertible {

        /// No compression framing.
        case disabled
        
        /// Framing compatible with `comp-lzo` (deprecated in 2.4).
        case compLZO

        /// Framing compatible with 2.4 `compress`.
        case compress
        
        var native: CompressionFramingNative {
            guard let val = CompressionFramingNative(rawValue: rawValue) else {
                fatalError("Unhandled CompressionFraming bridging")
            }
            return val
        }
        
        // MARK: CustomStringConvertible
        
        /// :nodoc:
        public var description: String {
            switch self {
            case .disabled:
                return "disabled"
                
            case .compress:
                return "compress"
                
            case .compLZO:
                return "comp-lzo"
            }
        }
    }
}
