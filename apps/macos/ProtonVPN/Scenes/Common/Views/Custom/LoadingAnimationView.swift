//
//  LoadingAnimationView.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa

class LoadingAnimationView: NSView {
    static let loadingAnimationSubdirectory = "LoadingAnimationFrames"

    private var gifView: GIFView!

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setup()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    private func setup() {
        clipToBounds()
        gifView = GIFView(frame: frame, pngDirectoryString: Self.loadingAnimationSubdirectory)
        gifView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(gifView)

        NSLayoutConstraint.activate([
            gifView.centerXAnchor.constraint(equalTo: centerXAnchor),
            gifView.centerYAnchor.constraint(equalTo: centerYAnchor),
            gifView.heightAnchor.constraint(equalTo: heightAnchor),
            gifView.widthAnchor.constraint(equalTo: widthAnchor)
        ])
    }

    func animate(_ animate: Bool) {
        gifView?.animate(animate)
    }
}
