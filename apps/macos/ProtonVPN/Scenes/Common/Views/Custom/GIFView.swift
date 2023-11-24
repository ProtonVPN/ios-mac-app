//
//  Created on 2022-03-24.
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
import ImageIO
import Cocoa

class GIFView: NSView {
    let frames: [CGImage]
    /// Caches the frames fetched & parsed from the file system.
    private static var frameCache: [String: [CGImage]] = [:]

    private let frameRate: TimeInterval = 1 / 45

    private var frameIndex: Int = 0
    private var animating: Bool = false
    private var timer: Timer?

    required init?(coder decoder: NSCoder) {
        fatalError("Not implemented: \(#function)")
    }

    init?(frame frameRect: NSRect, gifResourceURLString: String) {
        guard let frames = Self.getGifFrames(fromAssetURLString: gifResourceURLString) else {
            return nil
        }
        self.frames = frames
        super.init(frame: frameRect)
    }

    init?(frame frameRect: NSRect, pngDirectoryString: String) {
        guard let dirs = Bundle(for: type(of: self)).urls(forResourcesWithExtension: "png", subdirectory: pngDirectoryString) else {
            return nil
        }
        guard let frames = Self.getPngFrames(fromURLs: dirs) else {
            return nil
        }

        self.frames = frames
        super.init(frame: frameRect)
    }

    private static func getPngFrames(fromURLs urls: [URL]) -> [CGImage]? {
        guard let parentDir = urls.first?.deletingLastPathComponent().absoluteString else {
            return nil
        }

        if let frames = frameCache[parentDir] {
            return frames
        }

        let sortedFrameURLs = urls.sorted(by: { l, r -> Bool in
            l.lastPathComponent < r.lastPathComponent
        })

        var frames: [CGImage] = []
        for frameURL in sortedFrameURLs {
            guard let frameSource = CGImageSourceCreateWithURL(frameURL as CFURL, nil) else {
                return nil
            }
            guard let frame = CGImageSourceCreateImageAtIndex(frameSource, 0, nil) else {
                return nil
            }

            frames.append(frame)
        }

        frameCache[parentDir] = frames
        return frames
    }

    private static func getGifFrames(fromAssetURLString urlString: String) -> [CGImage]? {
        if let frames = frameCache[urlString] {
            return frames
        }

        let url = URL(fileURLWithPath: urlString)
        guard let data = try? Data(contentsOf: url), let frames = getGifFrames(from: data) else {
            return nil
        }

        frameCache[urlString] = frames
        return frames
    }

    private static func getGifFrames(from data: Data) -> [CGImage]? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let count = CGImageSourceGetCount(imageSource)
        var frames: [CGImage] = []
        for index in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(imageSource, index, nil) else {
                return nil
            }
            frames.append(frame)
        }
        return frames
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cgRect = dirtyRect as CGRect
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(frames[frameIndex], in: cgRect, byTiling: false)
    }

    func animate(_ play: Bool) {
        if !animating && play {
            animating = true
            timer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { _ in
                self.frameIndex = (self.frameIndex + 1) % self.frames.count
                self.needsDisplay = true
            }
        } else if animating && !play {
            animating = false
            timer?.invalidate()
            timer = nil
        }
    }
}
