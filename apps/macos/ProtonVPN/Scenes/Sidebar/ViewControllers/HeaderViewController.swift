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

import Announcement
import Cocoa
import Combine
import Dependencies
import Domain
import Ergonomics
import NATPMPUI
import SDWebImage
import SharedViews
import Theme
import VPNAppCore

final class HeaderViewController: NSViewController {
    private enum AccessibilityIdentifiers {
        static let ipLabel: String = "ipLabel"
        static let protocolLabel: String = "protocolLabel"
        static let headerLabel: String = "headerLabel"
    }

    // MARK: - Views

    private let backgroundView = NSView(frame: .zero).with { background in
        background.translatesAutoresizingMaskIntoConstraints = false
        background.wantsLayer = true
        DarkAppearance {
            background.layer?.backgroundColor = .cgColor(.background)
        }
    }

    private let flagView = FlagView(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let killSwitchIcon = NSImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageScaling = .scaleProportionallyUpOrDown
        $0.image = Theme.Asset.advancedKs.image
        $0.isHidden = true
    }

    private let headerLabel = HeaderViewController.makeLabel(horizontalHugging: 248)

    private let ipLabel = HeaderViewController.makeLabel(horizontalHugging: 249)
    private let loadLabel = HeaderViewController.makeLabel(horizontalHugging: 251)
    private let loadIcon = LoadCircle(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let protocolLabel = HeaderViewController.makeLabel(horizontalHugging: 249, horizontalCompressionResistance: 751)
    private let speedLabel = HeaderViewController.makeLabel(horizontalHugging: 251, horizontalCompressionResistance: 751)

    private lazy var connectButton = LargeConnectButton(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.target = self
        $0.action = #selector(quickConnectButtonAction)
    }

    private lazy var changeServerView = ChangeServerView(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.handler = changeServerButtonAction
    }

    private let announcementsContainer = NSView(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private lazy var announcementsButton = HoverDetectionButton(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imagePosition = .imageOnly
        $0.imageScaling = .scaleProportionallyDown
        $0.isHidden = true
        $0.target = self
        $0.action = #selector(announcementsButtonTapped(_:))
    }

    private let badgeView = NSView(frame: .zero).with { badge in
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.wantsLayer = true
        badge.layer?.cornerRadius = Dimensions.badgeCornerRadius
        DarkAppearance {
            badge.layer?.backgroundColor = .cgColor(.background, .info)
        }
        badge.isHidden = true
    }

    // MARK: - Stacks

    /// Header row: title pinned to the leading edge, announcements bell pushed to the trailing edge.
    private let headerStack = NSStackView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .horizontal
        $0.alignment = .centerY
        $0.distribution = .fill
        $0.spacing = Dimensions.stackSpacing
    }

    /// IP address on the leading edge, server load + load circle on the trailing edge.
    private let ipLoadStack = NSStackView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .horizontal
        $0.alignment = .centerY
        $0.distribution = .fill
        $0.spacing = Dimensions.rowSpacing
    }

    /// Protocol on the leading edge, transfer speed on the trailing edge.
    private let protocolSpeedStack = NSStackView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .horizontal
        $0.alignment = .centerY
        $0.distribution = .fill
        $0.spacing = Dimensions.rowSpacing
    }

    private let infoStackView = NSStackView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .vertical
        $0.alignment = .centerX
        $0.distribution = .fillEqually
        $0.spacing = Dimensions.stackSpacing
    }

    private let buttonStack = NSStackView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .vertical
        $0.alignment = .centerX
        $0.distribution = .fill
        $0.spacing = Dimensions.stackSpacing
    }

    private let contentStack = NSStackView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .vertical
        $0.alignment = .centerX
        $0.distribution = .fill
        $0.spacing = Dimensions.contentSpacing
    }

    private lazy var statusPortForwardingView = StatusPortAppKitView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isHidden = true
    }

    var announcementsButtonPressed: (() -> Void)?

    private var viewModel: HeaderViewModel!

    @Dependency(\.announcementManager) private var announcementManager
    private var announcementsCancellable: AnyCancellable?

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(viewModel: HeaderViewModel) {
        super.init(nibName: nil, bundle: nil)
        self.viewModel = viewModel
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Dimensions.rootWidth, height: Dimensions.rootHeight))
        setupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.delegate = self
        setupEphemeralView()
        viewModel.contentChanged = { [weak self] in self?.setupEphemeralView() }

        setupAnnouncements()

        announcementsCancellable = announcementManager.announcementsPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.setupAnnouncements() }
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

    // MARK: - Layout

    private func setupLayout() {
        [announcementsButton, badgeView].forEach(announcementsContainer.addSubview)

        [headerLabel, announcementsContainer].forEach(headerStack.addArrangedSubview)
        [ipLabel, loadLabel, loadIcon].forEach(ipLoadStack.addArrangedSubview)
        [protocolLabel, speedLabel].forEach(protocolSpeedStack.addArrangedSubview)
        [ipLoadStack, protocolSpeedStack].forEach(infoStackView.addArrangedSubview)
        [connectButton, changeServerView].forEach(buttonStack.addArrangedSubview)
        [killSwitchIcon, headerStack, infoStackView, buttonStack].forEach(contentStack.addArrangedSubview)

        view.addSubview(backgroundView)
        backgroundView.addSubview(flagView)
        flagView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            // Background and flag fill the root view.
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            flagView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            flagView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
            flagView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            flagView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),

            killSwitchIcon.widthAnchor.constraint(equalToConstant: 24),
            killSwitchIcon.heightAnchor.constraint(equalToConstant: 24),

            // Content stack inset within the flag view.
            contentStack.topAnchor.constraint(equalTo: flagView.topAnchor, constant: Dimensions.contentInsetVertical),
            contentStack.bottomAnchor.constraint(equalTo: flagView.bottomAnchor, constant: -Dimensions.contentInsetVertical),
            contentStack.leadingAnchor.constraint(equalTo: flagView.leadingAnchor, constant: Dimensions.contentInsetHorizontal),
            contentStack.trailingAnchor.constraint(equalTo: flagView.trailingAnchor, constant: -Dimensions.contentInsetHorizontal),

            // Each row spans the full width of its parent stack.
            headerStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            infoStackView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            infoStackView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            buttonStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),

            ipLoadStack.leadingAnchor.constraint(equalTo: infoStackView.leadingAnchor),
            ipLoadStack.trailingAnchor.constraint(equalTo: infoStackView.trailingAnchor),
            protocolSpeedStack.leadingAnchor.constraint(equalTo: infoStackView.leadingAnchor),
            protocolSpeedStack.trailingAnchor.constraint(equalTo: infoStackView.trailingAnchor),

            connectButton.leadingAnchor.constraint(equalTo: buttonStack.leadingAnchor),
            connectButton.trailingAnchor.constraint(equalTo: buttonStack.trailingAnchor),
            changeServerView.leadingAnchor.constraint(equalTo: buttonStack.leadingAnchor),
            changeServerView.trailingAnchor.constraint(equalTo: buttonStack.trailingAnchor),
            connectButton.heightAnchor.constraint(equalToConstant: Dimensions.buttonHeight),

            loadIcon.widthAnchor.constraint(equalToConstant: Dimensions.loadIconSize),
            loadIcon.heightAnchor.constraint(equalToConstant: Dimensions.loadIconSize),

            // Announcements button container: button fills it, badge sits at the top trailing corner.
            announcementsButton.leadingAnchor.constraint(equalTo: announcementsContainer.leadingAnchor),
            announcementsButton.trailingAnchor.constraint(equalTo: announcementsContainer.trailingAnchor),
            announcementsButton.topAnchor.constraint(equalTo: announcementsContainer.topAnchor),
            announcementsButton.bottomAnchor.constraint(equalTo: announcementsContainer.bottomAnchor),
            announcementsButton.widthAnchor.constraint(equalToConstant: Dimensions.announcementsSize),
            announcementsButton.heightAnchor.constraint(equalToConstant: Dimensions.announcementsSize),
            badgeView.topAnchor.constraint(equalTo: announcementsContainer.topAnchor),
            badgeView.trailingAnchor.constraint(equalTo: announcementsContainer.trailingAnchor),
            badgeView.widthAnchor.constraint(equalToConstant: Dimensions.badgeSize),
            badgeView.heightAnchor.constraint(equalToConstant: Dimensions.badgeSize),
        ])
    }

    private static func makeLabel(
        horizontalHugging: Float,
        horizontalCompressionResistance: Float? = nil
    ) -> NSTextField {
        NSTextField().with {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isEditable = false
            $0.isSelectable = false
            $0.isBordered = false
            $0.drawsBackground = false
            $0.focusRingType = .none
            $0.usesSingleLineMode = true
            $0.lineBreakMode = .byClipping
            $0.cell?.isScrollable = false
            $0.setContentHuggingPriority(.init(horizontalHugging), for: .horizontal)
            $0.setContentHuggingPriority(.init(750), for: .vertical)
            if let horizontalCompressionResistance {
                $0.setContentCompressionResistancePriority(.init(horizontalCompressionResistance), for: .horizontal)
            }
        }
    }

    // MARK: - Content

    private func setupEphemeralView() {
        setupFlagView()

        killSwitchIcon.isHidden = !viewModel.isKillSwitchBlocking

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

    /// Available width for the load label inside the IP/load row, accounting for the IP label, the
    /// load circle, and the inter-element spacing.
    private var horizontalSpaceAvailableForLoadLabel: CGFloat {
        let widthOfOtherElements = ipLabel.intrinsicContentSize.width + Dimensions.loadIconSize
        let padding = Dimensions.rowSpacing * 2
        return ipLoadStack.bounds.width - widthOfOtherElements - padding
    }

    private func setupLoad() {
        guard viewModel.isConnected,
              let loadDescription = viewModel.loadLabel,
              let loadDescriptionShort = viewModel.loadLabelShort,
              let loadPercentage = viewModel.loadPercentage else {
            loadLabel.isHidden = true
            loadIcon.isHidden = true
            return
        }

        // Fall back to the short "NN%" form when the full description doesn't fit, keeping the full
        // text available as a tooltip.
        if horizontalSpaceAvailableForLoadLabel < 10 + loadDescription.size().width {
            loadLabel.attributedStringValue = loadDescriptionShort
            loadLabel.toolTip = loadDescription.string
        } else {
            loadLabel.attributedStringValue = loadDescription
            loadLabel.toolTip = ""
        }

        loadLabel.isHidden = false
        loadIcon.load = loadPercentage
        loadIcon.isHidden = false
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
        guard statusPortForwardingView.superview == nil else { return }
        infoStackView.distribution = .fill
        infoStackView.alignment = .leading
        infoStackView.addArrangedSubview(statusPortForwardingView)
        statusPortForwardingView.setContentHuggingPriority(.required, for: .horizontal)
        statusPortForwardingView.setContentCompressionResistancePriority(.required, for: .horizontal)
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

    @objc
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
            DispatchQueue.main.async {
                self.statusPortForwardingView.portNumber = nil
                self.statusPortForwardingView.isHidden = true
            }
            return
        }
        DispatchQueue.main.async {
            self.statusPortForwardingView.portNumber = mappedPort
            self.statusPortForwardingView.invalidateIntrinsicContentSize()
            self.statusPortForwardingView.needsLayout = true
            self.infoStackView.needsLayout = true
            self.statusPortForwardingView.isHidden = false
        }
    }
}

private extension HeaderViewController {
    enum Dimensions {
        static let rootWidth: CGFloat = 432
        static let rootHeight: CGFloat = 224
        static let contentInsetVertical: CGFloat = 24
        static let contentInsetHorizontal: CGFloat = 40
        static let contentSpacing: CGFloat = 16
        static let stackSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 4
        static let buttonHeight: CGFloat = 40
        static let loadIconSize: CGFloat = 15
        static let announcementsSize: CGFloat = 24
        static let badgeSize: CGFloat = 6
        static let badgeCornerRadius: CGFloat = 3
    }
}
