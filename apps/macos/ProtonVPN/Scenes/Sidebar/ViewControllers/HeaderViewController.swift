//
//  HeaderViewController.swift
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

import SDWebImage

import Announcement
import Domain
import Ergonomics
import LegacyCommon
import NATPMPUI
import SwiftUI
import Theme

final class HeaderViewController: NSViewController {
    private enum AccessibilityIdentifiers {
        static let ipLabel: String = "ipLabel"
        static let protocolLabel: String = "protocolLabel"
        static let headerLabel: String = "headerLabel"
    }

    @IBOutlet private var backgroundView: NSView!
    @IBOutlet private var flagView: FlagView!
    @IBOutlet private var headerLabel: NSTextField!
    @IBOutlet private var ipLabel: NSTextField!
    @IBOutlet private var loadLabel: NSTextField!
    @IBOutlet private var loadIcon: LoadCircle!
    @IBOutlet private var speedLabel: NSTextField!
    @IBOutlet private var connectButton: LargeConnectButton!
    @IBOutlet private var changeServerView: ChangeServerView!
    @IBOutlet private var announcementsContainer: NSView!
    @IBOutlet private var announcementsButton: NSButton!
    @IBOutlet private var protocolLabel: NSTextField!
    @IBOutlet private var badgeView: NSView!

    @IBOutlet private var loadLabelLoadCircleHorizontalSpacing: NSLayoutConstraint!
    @IBOutlet private var ipLabelLoadLabelHorizontalSpacing: NSLayoutConstraint!
    @IBOutlet private var ipLoadRowContainer: NSView!
    @IBOutlet private var infoStackView: NSStackView!

    private var mappedPortModel = MappedPort()
    private lazy var statusNatPmpPortView = StatusPortView(portModel: mappedPortModel)
    private lazy var statusPortForwardingView = NSHostingView(rootView: statusNatPmpPortView).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isHidden = true
    }

    var announcementsButtonPressed: (() -> Void)?

    private var viewModel: HeaderViewModel!

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(viewModel: HeaderViewModel) {
        super.init(nibName: NSNib.Name("Header"), bundle: nil)
        self.viewModel = viewModel
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.delegate = self
        setupPersistentView()
        setupEphemeralView()
        viewModel.contentChanged = { [weak self] in self?.setupEphemeralView() }

        setupAnnouncements()
        setupBadgeView()

        AppEvent.announcementStorageContent.subscribe(self, selector: #selector(setupAnnouncements))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        viewModel.isVisible = true
        setupAnnouncements()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        viewModel.isVisible = false
    }

    private func setupPersistentView() {
        backgroundView.wantsLayer = true
        DarkAppearance {
            backgroundView.layer?.backgroundColor = .cgColor(.background)
        }

        connectButton.target = self
        connectButton.action = #selector(quickConnectButtonAction)

        changeServerView.handler = changeServerButtonAction
    }

    private func setupEphemeralView() {
        setupFlagView()

        headerLabel.attributedStringValue = viewModel.headerLabel
        headerLabel.setAccessibilityIdentifier(AccessibilityIdentifiers.headerLabel)
        ipLabel.attributedStringValue = viewModel.ipLabel
        ipLabel.setAccessibilityIdentifier(AccessibilityIdentifiers.ipLabel)

        setupLoad()
        setupProtocol()
        setupBitrate()

        setupButtons()
        setupPFView()
    }

    private func setupFlagView() {
        if viewModel.isConnected, let countryCode = viewModel.connectedCountryCode {
            flagView.backgroundImage = AppTheme.Icon.flag(countryCode: countryCode, style: .large)
        } else if !viewModel.isConnected, flagView.backgroundImage != nil {
            flagView.backgroundImage = nil
        }
    }

    private var horizontalSpaceAvailableForLoadLabel: CGFloat {
        let widthOfOtherElements = ipLabel.intrinsicContentSize.width + loadIcon.intrinsicContentSize.width
        let padding = ipLabelLoadLabelHorizontalSpacing.constant + loadLabelLoadCircleHorizontalSpacing.constant

        return ipLoadRowContainer.bounds.width - widthOfOtherElements - padding
    }

    private func setupLoad() {
        if viewModel.isConnected, let loadDescription = viewModel.loadLabel, let loadDescriptionShort = viewModel.loadLabelShort, let loadPercentage = viewModel.loadPercentage {
            if horizontalSpaceAvailableForLoadLabel < 10 + loadDescription.size().width {
                loadLabel.attributedStringValue = loadDescriptionShort
                loadLabel.toolTip = loadDescription.string
            } else {
                loadLabel.attributedStringValue = loadDescription
                loadLabel.toolTip = ""
            }

            loadLabel.isHidden = false
            loadIcon.load = loadPercentage
            loadIcon.toolTip = loadDescription.string
            loadIcon.isHidden = false
        } else {
            loadLabel.isHidden = true
            loadIcon.isHidden = true
        }
    }

    private func setupProtocol() {
        guard viewModel.isConnected, let vpnProcol = viewModel.vpnProtocol else {
            protocolLabel.isHidden = true
            return
        }

        protocolLabel.isHidden = false
        protocolLabel.attributedStringValue = vpnProcol
        protocolLabel.setAccessibilityIdentifier(AccessibilityIdentifiers.protocolLabel)
    }

    private func setupBitrate() {
        if viewModel.isConnected {
            speedLabel.isHidden = false
        } else {
            speedLabel.isHidden = true
        }
    }

    private func setupButtons(with state: ServerChangeViewState? = nil) {
        connectButton.isConnected = viewModel.isConnected
        let shouldShowChangeServer = viewModel.shouldShowChangeServer
        if shouldShowChangeServer {
            let viewState = state ?? ServerChangeViewState.from(state: viewModel.canChangeServer)
            changeServerView.state = viewState
        }

        changeServerView.isHidden = !shouldShowChangeServer
    }

    private func setupPFView() {
        infoStackView.addArrangedSubview(statusPortForwardingView)
        statusPortForwardingView.widthAnchor.constraint(equalTo: infoStackView.widthAnchor).isActive = true
    }

    @objc
    private func quickConnectButtonAction() {
        viewModel.quickConnectAction()
    }

    @objc
    private func changeServerButtonAction() {
        viewModel.changeServerAction()
    }

    // MARK: Announcements

    fileprivate func setupBadgeView() {
        badgeView.wantsLayer = true
        badgeView.layer?.cornerRadius = 3
        DarkAppearance {
            badgeView.layer?.backgroundColor = .cgColor(.background, .info)
        }
        badgeView.isHidden = true
    }

    @objc
    func setupAnnouncements() {
        guard let viewModel else {
            announcementsButton.isHidden = true
            return
        }
        Task {
            await viewModel.prefetchImages()

            guard viewModel.showAnnouncements else {
                announcementsButton.isHidden = true
                return
            }
            setupAnnouncementsButton()
        }
    }

    private func setupAnnouncementsButton() {
        let setup = { [weak self] (image: NSImage) in
            self?.announcementsButton.image = image
            self?.announcementsButton.isHidden = false
            self?.badgeView.isHidden = self?.viewModel.hasUnreadAnnouncements != true
        }

        announcementsButton.toolTip = viewModel.announcementTooltip
        announcementsButton.isHidden = true
        guard let iconUrl = viewModel.announcementIconUrl else {
            setup(AppTheme.Icon.bell)
            return
        }

        if let cached = SDImageCache.shared.imageFromCache(forKey: iconUrl.absoluteString) {
            setup(cached)
            return
        }

        let downloader = SDWebImageDownloader()
        downloader.downloadImage(with: iconUrl) { [weak self] image, _, _, _ in
            if let icon = image {
                SDImageCache.shared.store(icon, forKey: iconUrl.absoluteString, completion: nil)
                setup(icon)
            } else if self?.announcementsButton.image == nil {
                setup(AppTheme.Icon.bell)
            }
        }
    }

    @IBAction
    private func announcementsButtonTapped(_: Any) {
        announcementsButtonPressed?()
    }
}

extension HeaderViewController: HeaderViewModelDelegate {
    func changeServerStateUpdated(to state: ServerChangeViewState) {
        setupButtons(with: state)
    }

    func bitrateUpdated(with attributedString: NSAttributedString) {
        speedLabel.attributedStringValue = attributedString
    }

    func mappedPortChanged(to mappedPort: UInt16?) {
        guard let mappedPort else {
            // hide port view on nil
            statusPortForwardingView.isHidden = true
            return
        }
        statusPortForwardingView.isHidden = false
        DispatchQueue.main.async {
            self.mappedPortModel.portNumber = mappedPort
        }
    }
}
