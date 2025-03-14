//
//  LinkOpener.swift
//  VPNAppCore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  VPNAppCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  VPNAppCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with VPNAppCore.  If not, see <https://www.gnu.org/licenses/>.

#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

import Dependencies
import PMLogger
import Domain

public struct LinkOpener: DependencyKey {
    public let open: (URL) -> Void

    public func open(_ link: VPNLink) {
        open(link.url)
    }

    public func open(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            log.assertionFailure("Invalid url: \(urlString)")
            return
        }

        open(url)
    }

    public static var liveValue: LinkOpener = .init { url in
        #if canImport(UIKit)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        #elseif canImport(Cocoa)
        NSWorkspace.shared.open(url)
        #endif
    }

    #if DEBUG
    static let testLinkOpenerOpenedURL = Notification.Name("TestLinkOpenerOpenedURL")

    public static var testValue: LinkOpener = .init { url in
        NotificationCenter.default.post(name: Self.testLinkOpenerOpenedURL, object: url)
    }
    #endif
}

extension DependencyValues {
    public var linkOpener: LinkOpener {
        get { self[LinkOpener.self] }
        set { self[LinkOpener.self] = newValue }
    }
}
