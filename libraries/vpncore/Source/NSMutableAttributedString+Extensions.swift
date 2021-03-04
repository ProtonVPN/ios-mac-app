//
//  NSMutableAttributedString+Extensions.swift
//  vpncore - Created on 26.02.2021.
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
#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

// MARK: - Links

extension NSMutableAttributedString {

    /// Add a `.link` attribute to a given text
    /// - Parameters:
    ///     - links: Parameters to pass to `add(link: String, withUrl url: String)` method
    public func add(links: [(String, String)]) -> NSMutableAttributedString {
        for (link, url) in links {
            _ = self.add(link: link, withUrl: url)
        }
        return self
    }

    /// Add a `.link` attribute to a given text
    /// - Parameters:
    ///     - link: Text that will become a link
    ///     - withUrl: String representation or URL for a link
    public func add(link: String, withUrl: String) -> NSMutableAttributedString {
        let fullText = self.string
        guard let url = URL(string: withUrl), let subrange = fullText.range(of: link) else {
            return self
        }
        let nsRange = NSRange(subrange, in: fullText)
        self.addAttribute(.link, value: url, range: nsRange)

        return self
    }

}
