//
//  String+Cleanup.swift
//  vpncore - Created on 2020-06-16.
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
//

import Foundation

extension String {
    
    /// String cleaned up from the info that should not go to logs
    var cleanedForLog: String {
        do {
            let regex = try NSRegularExpression(pattern: "IP=(?:[0-9]{1,3}\\.){3}[0-9]{1,3}", options: NSRegularExpression.Options.caseInsensitive)
            let range = NSRange(location: 0, length: self.count)
            let cleanString = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "IP=X.X.X.X")
            return cleanString
            
        } catch {
            return self
        }
    }
    
    public func removeLastSubstring( _ separator: Character )-> String {
        guard let last = self.index(of: separator) else {
            return self
        }
        return String(self[startIndex..<last])
    }
}
