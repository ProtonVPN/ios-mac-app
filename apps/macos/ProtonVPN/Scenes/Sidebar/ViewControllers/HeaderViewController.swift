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
import LegacyCommon
import Theme
import Ergonomics

final class HeaderViewController: NSViewController {
    
    private enum AccessibilityIdentifiers {
        static let ipLabel: String = "ipLabel"
        static let protocolLabel: String = "protocolLabel"
    }

    @IBOutlet private weak var backgroundView: NSView!
    @IBOutlet private weak var flagView: FlagView!
    @IBOutlet private weak var headerLabel: NSTextField!
    @IBOutlet private weak var ipLabel: NSTextField!
    @IBOutlet private weak var loadLabel: NSTextField!
    @IBOutlet private weak var loadIcon: LoadCircle!
    @IBOutlet private weak var speedLabel: NSTextField!
    @IBOutlet private weak var connectButton: LargeConnectButton!
    @IBOutlet private weak var changeServerView: ChangeServerView!
    @IBOutlet private weak var announcementsContainer: NSView!
    @IBOutlet private weak var announcementsButton: NSButton!
    @IBOutlet private weak var protocolLabel: NSTextField!
    @IBOutlet private weak var badgeView: NSView!

    @IBOutlet private weak var loadLabelLoadCircleHorizontalSpacing: NSLayoutConstraint!
    @IBOutlet private weak var ipLabelLoadLabelHorizontalSpacing: NSLayoutConstraint!
    @IBOutlet private weak var ipLoadRowContainer: NSView!

    var announcementsButtonPressed: (() -> Void)?
    
    private var viewModel: HeaderViewModel!
    
    required init?(coder: NSCoder) {
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
        NotificationCenter.default.addObserver(self, selector: #selector(setupAnnouncements), name: AnnouncementStorageNotifications.contentChanged, object: nil)
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
        ipLabel.attributedStringValue = viewModel.ipLabel
        ipLabel.setAccessibilityIdentifier(AccessibilityIdentifiers.ipLabel)
        
        setupLoad()
        setupProtocol()
        setupBitrate()
        
        setupButtons()
    }
    
    private func setupFlagView() {
        if viewModel.isConnected, let countryCode = viewModel.connectedCountryCode {
            flagView.backgroundImage = AppTheme.Icon.flag(countryCode: countryCode, style: .large)
        } else if !viewModel.isConnected && flagView.backgroundImage != nil {
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
    
    @objc private func quickConnectButtonAction() {
        viewModel.quickConnectAction()
    }

    @objc private func changeServerButtonAction() {
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

    @objc func setupAnnouncements() {
        guard let viewModel = viewModel else {
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
        downloader.downloadImage(with: iconUrl) { [weak self] (image, _, _, _) in
            if let icon = image {
                SDImageCache.shared.store(icon, forKey: iconUrl.absoluteString, completion: nil)
                setup(icon)
            } else if self?.announcementsButton.image == nil {
                setup(AppTheme.Icon.bell)
            }
        }
    }
    
    @IBAction private func announcementsButtonTapped(_ sender: Any) {
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
}
