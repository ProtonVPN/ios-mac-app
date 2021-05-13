//
//  CoreConfiguration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/1/17.
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

class CoreConfiguration {
    static let identifier = "com.algoritmico.TunnelKit"
    
    static let version: String = {
        let bundle = Bundle(for: CoreConfiguration.self)
        guard let info = bundle.infoDictionary else {
            return ""
        }
//        guard let version = info["CFBundleShortVersionString"] as? String else {
//            return ""
//        }
//        guard let build = info["CFBundleVersion"] as? String else {
//            return version
//        }
//        return "\(version) (\(build))"
        return info["CFBundleShortVersionString"] as? String ?? ""
    }()

    // configurable
    static var masksPrivateData = true

    static var versionIdentifier: String?
    
    static let logsSensitiveData = false

    static var reconnectionDelay = 2.0
}

extension CustomStringConvertible {
    var maskedDescription: String {
        guard CoreConfiguration.masksPrivateData else {
            return description
        }
//        var data = description.data(using: .utf8)!
//        let dataCount = CC_LONG(data.count)
//        var md = Data(count: Int(CC_SHA1_DIGEST_LENGTH))
//        md.withUnsafeMutableBytes {
//            _ = CC_SHA1(&data, dataCount, $0.bytePointer)
//        }
//        return "#\(md.toHex().prefix(16))#"
        return "<masked>"
    }
}
