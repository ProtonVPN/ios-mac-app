//
//  MemoryDestination.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 7/26/17.
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
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation
import SwiftyBeaver

/// Implements a `SwiftyBeaver.BaseDestination` logging to a memory buffer.
public class MemoryDestination: BaseDestination, CustomStringConvertible {
    private var buffer: [String] = []

    /// Max number of retained lines.
    public var maxLines: Int?

    /// :nodoc:
    public override init() {
        super.init()
        asynchronously = false
    }
    
    /**
     Starts logging. Optionally prepend an array of lines.

     - Parameter existing: The optional lines to prepend (none by default).
     **/
    public func start(with existing: [String] = []) {
        execute(synchronously: true) {
            self.buffer = existing
        }
    }

    /**
     Flushes the log content to an URL.
     
     - Parameter url: The URL to write the log content to.
     **/
    public func flush(to url: URL) {
        execute(synchronously: true) {
            let content = self.buffer.joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: BaseDestination

    // XXX: executed in SwiftyBeaver queue. DO NOT invoke execute* here (sync in sync would crash otherwise)
    /// :nodoc:
    public override func send(_ level: SwiftyBeaver.Level, msg: String, thread: String, file: String, function: String, line: Int, context: Any?) -> String? {
        guard let message = super.send(level, msg: msg, thread: thread, file: file, function: function, line: line) else {
            return nil
        }
        buffer.append(message)
        if let maxLines = maxLines {
            while buffer.count > maxLines {
                buffer.removeFirst()
            }
        }
        return message
    }

    // MARK: CustomStringConvertible
    
    /// :nodoc:
    public var description: String {
        return executeSynchronously {
            return self.buffer.joined(separator: "\n")
        }
    }
}
