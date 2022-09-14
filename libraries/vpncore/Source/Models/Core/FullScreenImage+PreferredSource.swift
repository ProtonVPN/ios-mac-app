//
//  Created on 01/09/2022.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public extension FullScreenImage {
    func preferredSource() -> URL? {
        #if os(iOS)
        let maxWidth = UIScreen.main.bounds.width * UIScreen.main.scale
        #elseif os(macOS)
        let maxWidth: CGFloat = 600 * (NSScreen.main?.backingScaleFactor ?? 1)
        #endif

        enum Target: String {
            case phone = "Phone"
            case desktop = "Desktop"
        }

        struct URLSource {
            let url: URL
            let width: CGFloat

            init?(source: Source) {
                guard let width = source.width,
                      source.type == "PNG",
                      let url = URL(string: source.url) else {
                    return nil
                }
                self.url = url
                self.width = CGFloat(width)
            }
        }

        return source
            .compactMap(URLSource.init(source:))
            .first?.url
//            .sorted { $0.width > $1.width } // swiftlint:ignore:this sorted_first_last
//            .first {
//                $0.width <= maxWidth
//            }?.url
    }
}
