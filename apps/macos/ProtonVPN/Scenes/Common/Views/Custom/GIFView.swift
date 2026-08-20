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

import Cocoa
import Foundation
import ImageIO
import QuartzCore

/// Plays a folder of numbered PNGs as an animation.
@MainActor
final class GIFView: NSView {
    /// What the view is doing.
    ///
    /// `.loading` covers the gap while a background task reads the frames, so a second `animate(true)`
    /// in that window does not start a second read, and a stop in that window is noticed once the read
    /// finishes.
    private enum Playback {
        case stopped
        case loading
        case playing(CADisplayLink)
    }

    /// How long each frame stays on screen.
    private static let frameDuration: TimeInterval = 1 / 45

    private let frameURLs: [URL]

    @Invalidating(.display) private var frames: [CGImage] = []
    @Invalidating(.display) private var frameIndex: Int = 0

    private var playback: Playback = .stopped
    /// When the current run started, taken from the first callback because a display link has no
    /// timestamp until it has fired once.
    private var startTimestamp: CFTimeInterval?

    private var isPlaying: Bool {
        if case .stopped = playback {
            return false
        }
        return true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Not implemented: \(#function)")
    }

    init?(frame frameRect: NSRect, pngDirectoryString: String) {
        guard let urls = Bundle(for: GIFView.self)
            .urls(forResourcesWithExtension: "png", subdirectory: pngDirectoryString)
        else {
            return nil
        }

        self.frameURLs = urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        super.init(frame: frameRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard frameIndex < frames.count, let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(frames[frameIndex], in: dirtyRect as CGRect, byTiling: false)
    }

    func animate(_ play: Bool) {
        guard play != isPlaying else { return }

        if play {
            startReadingFrames()
        } else {
            stop()
        }
    }

    private func startReadingFrames() {
        playback = .loading

        let urls = frameURLs
        Task.detached(priority: .userInitiated) {
            let frames = decodeFrames(at: urls)
            await self.play(frames)
        }
    }

    private func play(_ frames: [CGImage]) {
        // The caller can have stopped us while the read was still going.
        guard case .loading = playback, !frames.isEmpty else { return }

        self.frames = frames
        frameIndex = 0
        startTimestamp = nil

        // A display link is not invoked while the view is hidden or off every display, so a popover the
        // user has closed costs nothing until they open it again.
        let link = displayLink(target: self, selector: #selector(showFrameForNow))
        link.add(to: .current, forMode: .common)
        playback = .playing(link)
    }

    @objc
    private func showFrameForNow(_ link: CADisplayLink) {
        guard !frames.isEmpty else { return }

        guard let startTimestamp else {
            startTimestamp = link.timestamp
            return
        }

        let index = Int((link.timestamp - startTimestamp) / Self.frameDuration) % frames.count
        // The display can be running faster than the animation, so most callbacks want the frame that is
        // already up. Assigning only on a change keeps the redraws down to the animation's own rate.
        guard index != frameIndex else { return }
        frameIndex = index
    }

    private func stop() {
        if case let .playing(link) = playback {
            link.invalidate()
        }
        playback = .stopped
        startTimestamp = nil
        frames = []
        frameIndex = 0
    }
}

/// Reads every frame of a PNG animation and decodes it.
///
/// `kCGImageSourceShouldCacheImmediately` is the point of calling this on a background task. Without it
/// ImageIO hands back images that decode when something first draws them, which for 60 frames of 500 by
/// 500 artwork puts about 27 ms of decoding on the main thread during the first pass. Asking for it here
/// costs about 35 ms on the calling task instead, and the animation then runs at its steady cost from
/// the very first frame.
private func decodeFrames(at urls: [URL]) -> [CGImage] {
    let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
    return urls.compactMap { url in
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, options)
    }
}
