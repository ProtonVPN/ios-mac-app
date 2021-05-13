//
//  BidirectionalState.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/9/18.
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

/// A generic structure holding a pair of inbound/outbound states.
public class BidirectionalState<T> {
    private let resetValue: T

    /// The inbound state.
    public var inbound: T
    
    /// The outbound state.
    public var outbound: T
    
    /**
     Returns current state as a pair.
     
     - Returns: Current state as a pair, inbound first.
     */
    public var pair: (T, T) {
        return (inbound, outbound)
    }
    
    /**
     Inits state with a value that will later be reused by `reset()`.
     
     - Parameter value: The value to initialize with and reset to.
     */
    public init(withResetValue value: T) {
        inbound = value
        outbound = value
        resetValue = value
    }
    
    /**
     Resets state to the value provided with `init(withResetValue:)`.
     */
    public func reset() {
        inbound = resetValue
        outbound = resetValue
    }
}
