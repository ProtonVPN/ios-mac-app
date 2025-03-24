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

import Dependencies
import DependenciesMacros

@DependencyClient
public struct ImagePrefetcher {
    public var isImagePrefetched: (FullScreenImage) async -> Bool = { _ in reportIssue("\(Self.self).isImagePrefetched"); return false }
    public var containsImageForKey: (String) async -> Bool = { _ in reportIssue("\(Self.self).containsImageForKey"); return false }
    public var prefetchURLs: ([URL]) async -> Void
}

extension ImagePrefetcher: DependencyKey {
    public static let liveValue = ImagePrefetcher { fullScreenImage in
        guard let urlString = fullScreenImage.source.first?.url else {
            return false
        }
        return await withCheckedContinuation { continuation in
            SDImageCache.shared.containsImage(forKey: urlString, cacheType: .all) { cacheType in
                continuation.resume(returning: cacheType != .none)
            }
        }
    } containsImageForKey: { key in
        await withCheckedContinuation { continuation in
            SDImageCache.shared.containsImage(forKey: key, cacheType: .all) { cacheType in
                continuation.resume(returning: cacheType != .none)
            }
        }
    } prefetchURLs: { urls in
        await withCheckedContinuation { continuation in
            SDWebImagePrefetcher.shared.prefetchURLs(urls, progress: nil, completed: { finishedUrlsCount, skippedUrlsCount in
                log.debug("SDWebImagePrefetcher finished prefetching urls, finished urls count: \(finishedUrlsCount), skipped urls count: \(skippedUrlsCount)")
                continuation.resume()
            })
        }
    }

    #if DEBUG
    public static var testValue: ImagePrefetcher = Self()
    #endif
}

extension DependencyValues {
    public var imagePrefetcher: ImagePrefetcher {
        get { self[ImagePrefetcher.self] }
        set { self[ImagePrefetcher.self] = newValue }
    }
}
