//
//  CoreNewsRequest.swift
//  vpncore - Created on 2020-10-05.
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

import ProtonCoreNetworking
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class CoreApiNotificationsRequest {

    private let basePath = "/core/v4/notifications"

    private let supportedFormats: [ImageFormat] = [.png]

    private enum ImageFormat: String {
        case png = "PNG"
        case lottie = "LOTTIE"
        case gif = "GIF"
        case svg = "SVG"
    }

    private enum QueryItem: String {
        case formats = "FullScreenImageSupport"
        case width = "FullScreenImageWidth"
        case height = "FullScreenImageHeight"
    }

    private var supportedImageFormats: String {
        supportedFormats
            .map { $0.rawValue }
            .joined(separator: ",")
    }

    private var screenSize: CGSize {
#if canImport(UIKit)
        let size = UIScreen.main.sizeInPixels()
#elseif canImport(AppKit)
        let size = NSScreen.sizeInPixels()
#endif
        return size
    }

    private func queryItem(_ item: QueryItem, value: String) -> URLQueryItem {
        URLQueryItem(name: item.rawValue, value: value)
    }

    private func queryItems() -> [URLQueryItem] {
        [
            queryItem(.formats, value: supportedImageFormats),
            queryItem(.width, value: "\(screenSize.width)"),
            queryItem(.height, value: "\(screenSize.height)")
        ]
    }
}

extension CoreApiNotificationsRequest: Request {
    var path: String {
        var components = URLComponents(string: basePath)
        components?.queryItems = queryItems()
        return components?.url?.absoluteString ?? basePath
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }
}

#if canImport(UIKit)

extension UIScreen {
    func sizeInPixels() -> CGSize {
        let size = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        if UIDevice.current.isIpad {
            return size
                .scaled(by: scale)
                .horizontal()
        } else {
            return size.scaled(by: scale)
        }
    }
}

#elseif canImport(AppKit)

extension NSScreen {
    static func sizeInPixels() -> CGSize {
        let screen = NSApplication.shared.mainWindow?.screen
        let size = screen?.visibleFrame.size ?? CGSize(width: 1920, height: 1080) // fullHD
        return size.scaled(by: screen?.backingScaleFactor ?? 1)
    }
}

#endif

extension CGSize {
    fileprivate func scaled(by scale: CGFloat) -> CGSize {
        CGSize(width: width * scale, height: height * scale)
    }
    
    fileprivate func horizontal() -> CGSize {
        let newWidth = max(width, height)
        let newHeight = min(width, height)
        return CGSize(width: newWidth, height: newHeight)
    }
}
