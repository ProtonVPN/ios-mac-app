//
//  NSRegularExpression+Shortcuts.swift
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

extension NSRegularExpression {
    convenience init(_ pattern: String) {
        try! self.init(pattern: pattern, options: [])
    }

    func enumerateComponents(in string: String, using block: ([String]) -> Void) {
        enumerateMatches(in: string, options: [], range: NSMakeRange(0, string.count)) { (result, flags, stop) in
            guard let range = result?.range else {
                return
            }
            let match = (string as NSString).substring(with: range)
            let tokens = match.components(separatedBy: " ").filter { !$0.isEmpty }
            block(tokens)
        }
    }
    
    func enumerateArguments(in string: String, using block: ([String]) -> Void) {
        enumerateComponents(in: string) { (tokens) in
            var args = tokens
            args.removeFirst()
            block(args)
        }
    }
}
