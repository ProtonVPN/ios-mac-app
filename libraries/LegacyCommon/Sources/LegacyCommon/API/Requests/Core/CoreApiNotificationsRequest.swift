//
//  CoreNewsRequest.swift
//  vpncore - Created on 2020-10-05.
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
        let size = NSScreen.availableSizeInPixels()
#endif
        return size
    }

    private func queryItem(_ item: QueryItem, value: String) -> URLQueryItem {
        URLQueryItem(name: item.rawValue, value: value)
    }

    private func queryItems() -> [URLQueryItem] {
        [
            queryItem(.formats, value: supportedImageFormats),
            queryItem(.width, value: "\(Int(screenSize.width))"),
            queryItem(.height, value: "\(Int(screenSize.height))")
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
    public static func availableSizeInPixels() -> CGSize {
        guard let screen = NSScreen.main else {
            return CGSize(width: 1920, height: 1080) // fullHD
        }

        let visibleFrameSize = screen.visibleFrame.size
        let scaled = visibleFrameSize.scaled(by: screen.backingScaleFactor) // in pixels
        let fitting: CGSize
        if scaled.width > scaled.height {
            // If the frame * scale is higher than 4K, dial it down to 4K.
            fitting = scaled.fitting(CGSize(width: 3840, height: 2160))
        } else {
            fitting = scaled.fitting(CGSize(width: 2160, height: 3840))
        }
        let freeSpace = CGSize(width: fitting.width,
                               height: fitting.height - occupiedHeight(screen))
        return freeSpace
    }

    /// Height in pixels that we need to subtract because it's occupied by system.
    private static func occupiedHeight(_ screen: NSScreen) -> CGFloat {
        let isNotch: Bool
        if #available(macOS 12.0, *),
           let top = NSScreen.main?.safeAreaInsets.top {
            isNotch = top != 0
        } else {
            isNotch = false
        }

        let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ??  24
        let appTitleBarHeight: CGFloat = 28
        let notchAdditionalHeight: CGFloat = isNotch ? 12 : 0
        let buttonAndPaddingHeight: CGFloat = 40 + 2 * 32
        return screen.backingScaleFactor * 
        (menuBarHeight + notchAdditionalHeight + buttonAndPaddingHeight + appTitleBarHeight)
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
