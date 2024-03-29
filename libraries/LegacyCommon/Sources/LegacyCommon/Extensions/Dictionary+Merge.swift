//
//  Dictionary+Merge.swift
//  vpncore - Created on 2020-03-31.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

extension Dictionary where Key == String, Value == String {
    
    /// Merge two dictionaries. If duplicate key is found, value from the right dictionary is used.
    /// - Parameters:
    ///   - left: main dictionary used as a base.
    ///   - right: secondary dictionary that will be merged into `left` and overwrite values of duplicate keys.
    static func + (left: [Key: Value], right: [Key: Value]) -> [Key: Value] {
        return left.merging(right) { (leftValue, rightValue) in rightValue }
    }
    
}
