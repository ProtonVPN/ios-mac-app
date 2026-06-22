//
//  LaunchViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import Ergonomics
import UIKit

/// Layout mirrors `VPNLaunchScreen.storyboard`
final class LaunchViewController: UIViewController {
    enum AnimationMode {
        case delayed
        case immediate
    }

    var mode: AnimationMode = .delayed

    // MARK: - Subviews

    private let logoImageView = UIImageView(image: UIImage(resource: .launchScreenVPNLogo)).with {
        $0.contentMode = .scaleAspectFit
        $0.clipsToBounds = true
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let loadingIndicator = UIActivityIndicatorView(style: .large).with {
        $0.color = .white
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private var loadingIndicatorTimer: Timer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadingIndicator.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        switch mode {
        case .delayed:
            loadingIndicatorTimer?.invalidate()
            loadingIndicatorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.loadingIndicator.isHidden = false
            }
        case .immediate:
            loadingIndicator.isHidden = false
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        loadingIndicatorTimer?.invalidate()
        loadingIndicator.isHidden = true
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = UIColor(resource: .launchScreenVPNBackground)

        loadingIndicator.startAnimating()

        view.addSubview(logoImageView)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: Dimensions.logoImageViewWidth),
            logoImageView.heightAnchor.constraint(equalToConstant: Dimensions.logoImageViewHeight),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.widthAnchor.constraint(equalToConstant: Dimensions.loadingIndicatorWidth),
            loadingIndicator.heightAnchor.constraint(equalTo: loadingIndicator.widthAnchor),
            view.safeAreaLayoutGuide.bottomAnchor
                .constraint(equalTo: loadingIndicator.bottomAnchor, constant: Dimensions.bottomSpacing),
        ])
    }
}

private extension LaunchViewController {
    enum Dimensions {
        static let logoImageViewWidth: CGFloat = 128
        static let logoImageViewHeight: CGFloat = 128
        static let loadingIndicatorWidth: CGFloat = 35
        static let bottomSpacing: CGFloat = 140
    }
}
