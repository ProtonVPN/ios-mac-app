//
//  Created on 03/03/2023.
//
//  Copyright (c) 2023 Proton AG
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

import AVFoundation
import Combine

class VideoTourModel {
    enum VideoFile {
        case systemExtension

        var rawValue: String {
            switch self {
            case .systemExtension:
                if VideoTourModel.isPreVentura {
                    return "system-extension-video-tour-pre-ventura"
                } else {
                    return "system-extension-video-tour"
                }
            }
        }
    }

    private let videoFile: VideoFile
    private var cancellables = Set<AnyCancellable>()

    private lazy var urlAsset: AVURLAsset = {
        let path = Bundle.main.path(forResource: videoFile.rawValue, ofType: "mp4")!
        let videoUrl = URL(fileURLWithPath: path)
        return AVURLAsset(url: videoUrl)
    }()

    static var isPreVentura: Bool = {
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return systemVersion.majorVersion < 13
    }()

    lazy var size: CGSize = {
        guard let track = urlAsset.tracks(withMediaType: .video).first else {
            return .zero
        }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }()

    lazy var player = {
        let playerItem = AVPlayerItem(asset: urlAsset)
        let player = AVPlayer(playerItem: playerItem)
        return player
    }()

    init(videoFile: VideoFile) {
        self.videoFile = videoFile
    }

    func onAppear() {
        player.play()
        player.rate = 0.5
        NotificationCenter.default
            .publisher(for: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            .sink(receiveValue: itemDidPlayToEndTime)
            .store(in: &cancellables)
    }

    private func itemDidPlayToEndTime(_ notification: Notification) {
        player.seek(to: .zero)
        player.play()
    }
}
