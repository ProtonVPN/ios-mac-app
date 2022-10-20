//
//  Created on 26/09/2022.
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
import SDWebImage

public struct FullScreenImagePrefetcher {
    let imageCache: ImageCacheProtocol

    public typealias Factory = ImageCacheFactoryProtocol

    public init(_ factory: Factory) {
        imageCache = factory.makeImageCache()
    }

    public func isImagePrefetched(fullScreenImage: FullScreenImage) async -> Bool {
        guard let urlString = fullScreenImage.source.first?.url else {
            return false
        }
        return await imageCache.containsImageForKey(forKey: urlString)
    }

    public func prefetchImages(urls: [URL]) async {
        guard !urls.isEmpty else {
            log.debug("No URLs to prefetch")
            return
        }
        log.debug("Prefetching urls: \(urls)")
        await imageCache.prefetchURLs(urls)
    }
}

public protocol ImageCacheFactoryProtocol {
    func makeImageCache() -> ImageCacheProtocol
}

public struct ImageCacheFactory: ImageCacheFactoryProtocol {

    public init() { }

    public func makeImageCache() -> ImageCacheProtocol {
        ImageCache()
    }
}

public protocol ImageCacheProtocol {
    func containsImageForKey(forKey key: String) async -> Bool
    func prefetchURLs(_ urls: [URL]) async
}

struct ImageCache: ImageCacheProtocol {
    func containsImageForKey(forKey key: String) async -> Bool {
        await withCheckedContinuation { continuation in
            SDImageCache.shared.containsImage(forKey: key, cacheType: .all) { cacheType in
                continuation.resume(returning: cacheType != .none)
            }
        }
    }

    func prefetchURLs(_ urls: [URL]) async {
        await withCheckedContinuation { continuation in
            SDWebImagePrefetcher.shared.prefetchURLs(urls, progress: nil, completed: { finishedUrlsCount, skippedUrlsCount in
                log.debug("SDWebImagePrefetcher finished prefetching urls, finished urls count: \(finishedUrlsCount), skipped urls count: \(skippedUrlsCount)")
                continuation.resume()
            })
        }
    }
}
