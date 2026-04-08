//
//  CountriesSectionViewController.swift
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

import AppKit
import Cocoa

import Dependencies

import Countries
import Domain
import Ergonomics
import LegacyCommon
import Modals
import NetShield
import Strings
import Theme
import VPNShared

import ComposableArchitecture
import SwiftUI

final class CountriesSectionViewController: NSViewController {
    private let searchIcon = NSImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageScaling = .scaleProportionallyDown
    }

    private let searchTextField = TextFieldWithFocus(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let searchBox = NSBox().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.boxType = .custom
        $0.titlePosition = .noTitle
        $0.cornerRadius = AppTheme.ButtonConstants.cornerRadius
    }

    private let bottomHorizontalLine = NSBox().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.boxType = .custom
        $0.isTransparent = true
        $0.titlePosition = .noTitle
        $0.isHidden = true
    }

    private let countriesListView = NSView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let clearSearchBtn = NSButton().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isHidden = true
        $0.bezelStyle = .shadowlessSquare
        $0.isBordered = false
        $0.imagePosition = .imageOnly
        $0.imageScaling = .scaleProportionallyUpOrDown
    }

    private let quickSettingsStack = QuickSettingsStack(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.orientation = .horizontal
        $0.alignment = .centerY
        $0.distribution = .fillEqually
        $0.spacing = 0
        $0.detachesHiddenViews = true
        $0.setContentHuggingPriority(.init(250), for: .horizontal)
        $0.setContentHuggingPriority(.init(250), for: .vertical)
    }

    private let secureCoreBox = NSBox()
    private let netShieldBox = NSBox()
    private let killSwitchBox = NSBox()
    private let portForwardingBox = NSBox()

    let secureCoreBtn = QuickSettingButton(frame: .zero)
    let netShieldBtn = QuickSettingButton(frame: .zero)
    let killSwitchBtn = QuickSettingButton(frame: .zero)
    let portForwardingBtn = QuickSettingButton(frame: .zero)

    private var netShieldStatsLabel: NSTextField?

    fileprivate let viewModel: CountriesSectionViewModel

    private lazy var quickSettingsManager = QuickSettingsManager()

    private var notificationTokens: [NotificationToken] = []
    private var netShieldObserverTask: Task<Void, Never>?

    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider

    // MARK: - Life cycle

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(viewModel: CountriesSectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        viewModel.delegate = self
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        configureStaticSubviews()
        setupHierarchy()
        setupLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupSearchSection()
        setupTableView()
        setupQuickSettings()
        setupNetShieldBadge()
        addNetShieldObservers()
        observeAppearance()
        setupCountriesListView()
    }

    private func configureStaticSubviews() {
        configureQuickSettingBox(secureCoreBox, button: secureCoreBtn, icon: AppTheme.Icon.lock)
        configureQuickSettingBox(netShieldBox, button: netShieldBtn, icon: AppTheme.Icon.shield)
        configureQuickSettingBox(killSwitchBox, button: killSwitchBtn, icon: AppTheme.Icon.switchOn)
        configureQuickSettingBox(portForwardingBox, button: portForwardingBtn, icon: AppTheme.Icon.arrowUpBounceLeft)

        let statsLabel = NSTextField(labelWithString: "").with {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isHidden = true
            $0.isBordered = false
            $0.isEditable = false
            $0.isSelectable = false
            $0.focusRingType = .none
            $0.lineBreakMode = .byTruncatingTail
            $0.alignment = .center
            $0.font = .systemFont(ofSize: Dimensions.netShieldBadgeFontSize)
            $0.textColor = .white
            $0.drawsBackground = true
        }
        netShieldStatsLabel = statsLabel
        if let netShieldContentView = netShieldBox.contentView {
            netShieldContentView.addSubview(statsLabel)
        }
    }

    private func configureQuickSettingBox(_ box: NSBox, button: QuickSettingButton, icon: NSImage) {
        box.translatesAutoresizingMaskIntoConstraints = false
        box.boxType = .custom
        box.isTransparent = true
        box.contentViewMargins = .zero
        box.titlePosition = .noTitle
        box.cornerRadius = .themeRadius4
        box.fillColor = .clear

        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true
        button.bezelStyle = .shadowlessSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.image = icon

        guard let contentView = box.contentView else { return }
        contentView.addSubview(button)
    }

    private func setupHierarchy() {
        view.addSubview(bottomHorizontalLine)
        view.addSubview(quickSettingsStack)
        view.addSubview(searchBox)
        view.addSubview(countriesListView)

        quickSettingsStack.addArrangedSubview(secureCoreBox)
        quickSettingsStack.addArrangedSubview(netShieldBox)
        quickSettingsStack.addArrangedSubview(killSwitchBox)
        quickSettingsStack.addArrangedSubview(portForwardingBox)

        guard let searchContentView = searchBox.contentView else { return }
        searchContentView.addSubview(searchIcon)
        searchContentView.addSubview(searchTextField)
        searchContentView.addSubview(clearSearchBtn)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            quickSettingsStack.heightAnchor.constraint(equalToConstant: Dimensions.quickSettingsHeight),
            quickSettingsStack.topAnchor.constraint(equalTo: view.topAnchor, constant: Dimensions.quickSettingsTopOffset),
            quickSettingsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Dimensions.quickSettingsHorizontalInset),
            quickSettingsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Dimensions.quickSettingsHorizontalInset),

            searchBox.heightAnchor.constraint(equalToConstant: Dimensions.searchBoxHeight),
            searchBox.topAnchor.constraint(equalTo: quickSettingsStack.bottomAnchor),
            searchBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Dimensions.searchBoxHorizontalInset),
            searchBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Dimensions.searchBoxHorizontalInset),

            bottomHorizontalLine.heightAnchor.constraint(equalToConstant: Dimensions.separatorHeight),
            bottomHorizontalLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomHorizontalLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomHorizontalLine.topAnchor.constraint(equalTo: searchBox.bottomAnchor, constant: Dimensions.separatorTopOffset),

            countriesListView.topAnchor.constraint(equalTo: bottomHorizontalLine.topAnchor),
            countriesListView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            countriesListView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            countriesListView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        if let searchContentView = searchBox.contentView {
            NSLayoutConstraint.activate([
                searchIcon.widthAnchor.constraint(equalToConstant: Dimensions.searchIconSize),
                searchIcon.heightAnchor.constraint(equalToConstant: Dimensions.searchIconSize),
                searchIcon.leadingAnchor.constraint(equalTo: searchContentView.leadingAnchor, constant: Dimensions.searchIconLeading),
                searchIcon.centerYAnchor.constraint(equalTo: searchContentView.centerYAnchor),

                searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: Dimensions.searchFieldLeading),
                searchTextField.centerYAnchor.constraint(equalTo: searchIcon.centerYAnchor),

                clearSearchBtn.heightAnchor.constraint(equalToConstant: Dimensions.clearButtonSize),
                clearSearchBtn.widthAnchor.constraint(equalTo: clearSearchBtn.heightAnchor),
                clearSearchBtn.leadingAnchor.constraint(equalTo: searchTextField.trailingAnchor, constant: Dimensions.clearButtonLeading),
                clearSearchBtn.trailingAnchor.constraint(equalTo: searchContentView.trailingAnchor, constant: Dimensions.clearButtonTrailing),
                clearSearchBtn.centerYAnchor.constraint(equalTo: searchContentView.centerYAnchor),
            ])
        }

        setupQuickSettingButtonLayout(for: secureCoreBox, button: secureCoreBtn)
        setupQuickSettingButtonLayout(for: netShieldBox, button: netShieldBtn)
        setupQuickSettingButtonLayout(for: killSwitchBox, button: killSwitchBtn)
        setupQuickSettingButtonLayout(for: portForwardingBox, button: portForwardingBtn)
        setupQuickSettingBoxLayout()

        if let statsLabel = netShieldStatsLabel,
           let netShieldContentView = netShieldBox.contentView {
            NSLayoutConstraint.activate([
                statsLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.netShieldBadgeMinWidth),
                statsLabel.heightAnchor.constraint(equalToConstant: Dimensions.netShieldBadgeHeight),
                statsLabel.centerXAnchor.constraint(equalTo: netShieldContentView.centerXAnchor, constant: Dimensions.netShieldBadgeCenterXOffset),
                statsLabel.centerYAnchor.constraint(equalTo: netShieldContentView.centerYAnchor, constant: Dimensions.netShieldBadgeCenterYOffset),
            ])
        }
    }

    private func setupQuickSettingButtonLayout(for box: NSBox, button: QuickSettingButton) {
        guard let contentView = box.contentView else { return }
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Dimensions.quickSettingButtonInset),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Dimensions.quickSettingButtonInset),
            button.heightAnchor.constraint(equalToConstant: Dimensions.quickSettingButtonHeight),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: Dimensions.quickSettingButtonCenterYOffset),
        ])
    }

    private func setupQuickSettingBoxLayout() {
        NSLayoutConstraint.activate([
            secureCoreBox.topAnchor.constraint(equalTo: quickSettingsStack.topAnchor),
            secureCoreBox.bottomAnchor.constraint(equalTo: quickSettingsStack.bottomAnchor),
            netShieldBox.topAnchor.constraint(equalTo: quickSettingsStack.topAnchor),
            netShieldBox.bottomAnchor.constraint(equalTo: quickSettingsStack.bottomAnchor),
            killSwitchBox.topAnchor.constraint(equalTo: quickSettingsStack.topAnchor),
            killSwitchBox.bottomAnchor.constraint(equalTo: quickSettingsStack.bottomAnchor),
            portForwardingBox.topAnchor.constraint(equalTo: quickSettingsStack.topAnchor),
            portForwardingBox.bottomAnchor.constraint(equalTo: quickSettingsStack.bottomAnchor),
        ])
    }

    func setupCountriesListView() {
        let countriesView = CountriesListView(store: viewModel.store)
        let hostingView = NSHostingView(rootView: countriesView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        countriesListView.addSubview(hostingView)
        countriesListView.addConstraints([
            countriesListView.leadingAnchor.constraint(equalTo: hostingView.leadingAnchor),
            countriesListView.trailingAnchor.constraint(equalTo: hostingView.trailingAnchor),
            countriesListView.topAnchor.constraint(equalTo: hostingView.topAnchor),
            countriesListView.bottomAnchor.constraint(equalTo: hostingView.bottomAnchor),
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        quickSettingsManager.hideAllSettings()
    }

    override func viewDidLayout() {
        netShieldBtn.layoutSubtreeIfNeeded()
        secureCoreBtn.layoutSubtreeIfNeeded()
        killSwitchBtn.layoutSubtreeIfNeeded()
        portForwardingBtn.layoutSubtreeIfNeeded()
    }

    var observer: Any?

    /// Appearance change doesn't get propagated normally, so we have to manually update the colors when user changes appearance
    func observeAppearance() {
        observer = NSApp.observe(\.effectiveAppearance, options: [.new, .old, .initial, .prior]) { [weak self] _, change in
            guard let newValue = change.newValue else { return }
            newValue.performAsCurrentDrawingAppearance {
                self?.setupColors()
            }
        }
    }

    // MARK: - Private

    private func setupView() {
        view.wantsLayer = true

        secureCoreBtn.setAccessibilityChildren([secureCoreBox as Any])
        netShieldBtn.setAccessibilityChildren([netShieldBox as Any])
        killSwitchBtn.setAccessibilityChildren([killSwitchBox as Any])
        if VPNFeatureFlagType.portForwarding.enabled {
            portForwardingBox.isHidden = false
            portForwardingBtn.setAccessibilityChildren([portForwardingBox as Any])
        } else {
            portForwardingBox.isHidden = true
        }
    }

    private func setupColors() {
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
            searchBox.layer?.backgroundColor = .cgColor(.background)
        }

        bottomHorizontalLine.fillColor = .color(.border, .weak)
        searchIcon.image = AppTheme.Icon.magnifier.colored(.hint)
        clearSearchBtn.image = AppTheme.Icon.crossCircleFilled.colored(.hint)

        searchBox.borderColor = .color(.border)

        controlTextDidEndEditing(.init(name: .init(rawValue: "")))
    }

    private func setupSearchSection() {
        searchIcon.cell?.setAccessibilityElement(false)

        clearSearchBtn.target = self
        clearSearchBtn.action = #selector(clearSearch)
        // The line below was commented out to fix UI tests
        // clearSearchBtn.cell?.setAccessibilityElement(false)

        searchTextField.focusDelegate = self
        searchTextField.delegate = self
        searchTextField.usesSingleLineMode = true
        searchTextField.focusRingType = .none
        searchTextField.style(placeholder: Localizable.searchForCountry, font: .themeFont(.heading4), alignment: .left)
        searchBox.cornerRadius = AppTheme.ButtonConstants.cornerRadius

        searchTextField.setAccessibilityIdentifier("SearchTextField")
        clearSearchBtn.setAccessibilityIdentifier("ClearSearchButton")
    }

    private func setupTableView() {
        viewModel.contentChanged = { [weak self] change in self?.contentChanged(change) }
        viewModel.displayPremiumServices = { [weak self] in
            self?.presentAsSheet(FeaturesOverlayViewController(viewModel: PremiumFeaturesOverlayViewModel()))
        }
        viewModel.displayStreamingServices = { [weak self] in
            self?.presentAsSheet(StreamingServicesOverlayViewController(viewModel: StreamingServicesOverlayViewModel(country: $0, streamServices: $1)))
        }
        viewModel.displayGatewaysServices = { [weak self] in
            self?.presentAsSheet(FeaturesOverlayViewController(viewModel: GatewayFeaturesOverlayViewModel()))
        }
    }

    private func setupQuickSettings() {
        quickSettingsManager.delegate = self
        quickSettingsManager.setup(with: viewModel, in: self)

        // hides netshield quick setting button
        netShieldBox.isHidden = !viewModel.isNetShieldEnabled
        viewModel.updateSettings()
    }

    // MARK: - NetShield Badge

    private func setupNetShieldBadge() {
        guard let netShieldPresenter = (viewModel.netShieldPresenter as? NetshieldDropdownPresenter) else {
            return
        }

        guard netShieldPresenter.isNetShieldStatsEnabled else {
            netShieldStatsLabel?.removeFromSuperview()
            return
        }
        netShieldStatsLabel?.wantsLayer = true
        netShieldStatsLabel?.layer?.cornerRadius = Dimensions.netShieldBadgeCornerRadius
        netShieldStatsLabel?.backgroundColor = .color(.background)

        DispatchQueue.main.async {
            self.updateNetShieldBadge()
        }
    }

    private func updateNetShieldBadge() {
        guard let presenter = viewModel.netShieldPresenter as? NetshieldDropdownPresenter else { return }

        if presenter.appStateManager.displayState != .connected {
            netShieldStatsLabel?.isHidden = true
        } else {
            netShieldStatsLabel?.isHidden = false
        }

        updateStats(stats: presenter.netShieldStats)
        if presenter.netShieldPropertyProvider.getNetShieldType() != .level2 {
            updateStats(stats: .zero(enabled: false))
        }
    }

    private func updateStats(stats: NetShieldModel) {
        netShieldStatsLabel?.isEnabled = stats.enabled
        let badge = (stats.adsCount + stats.trackersCount) >= 99 ? "99+" : "\(stats.adsCount + stats.trackersCount)"
        netShieldStatsLabel?.stringValue = badge
    }

    private func addNetShieldObservers() {
        notificationTokens.append(NotificationCenter.default.addObserver(
            for: NetShieldStatsNotification.self,
            object: nil
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNetShieldBadge()
            }
        })

        // Observe NetShield type changes via AsyncStream
        netShieldObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = netShieldPropertyProvider.netShieldTypeStream()
            for await netShieldType in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    if netShieldType != .level2 {
                        self.updateStats(stats: .zero(enabled: false))
                    }
                }
            }
        }
    }

    deinit {
        netShieldObserverTask?.cancel()
    }

    // MARK: - Port forwarding

    private func updatePortForwardingView() {
        guard VPNFeatureFlagType.portForwarding.enabled else { return }
        @Dependency(\.natPortMappingService) var natPortMappingService
        if case .failure = natPortMappingService.portMappingStream.value {
            quickSettingsManager.updateState(connectionInfo: .pfError(isConnected: viewModel.isConnected))
            return
        }
        let connectionInfo = ConnectionInfo.connected(
            portForwardingEnabled: viewModel.portForwardingIsOn,
            supportsP2P: viewModel.connectedServerSupportsP2P,
            isConnected: viewModel.isConnected
        )
        quickSettingsManager.updateState(connectionInfo: connectionInfo)
    }

    @objc
    private func clearSearch() {
        if searchTextField.stringValue.isEmpty { return }
        searchTextField.stringValue = ""
        clearSearchBtn.isHidden = true
        viewModel.filterContent(forQuery: "")
    }

    private func contentChanged(_: ContentChange) {
        updatePortForwardingView()
    }
}

extension CountriesSectionViewController: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        clearSearchBtn.isHidden = searchTextField.stringValue.isEmpty
        viewModel.filterContent(forQuery: searchTextField.stringValue)
    }

    func controlTextDidEndEditing(_: Notification) {
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            searchIcon.image = searchIcon.image?.colored(.weak)
            searchBox.borderColor = .color(.border)
        }
    }
}

extension CountriesSectionViewController: TextFieldFocusDelegate {
    /// Don't focus on search field when countries view is displayed
    var shouldBecomeFirstResponder: Bool { false }

    func willReceiveFocus(_: NSTextField) {
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            searchIcon.image = searchIcon.image?.colored(.normal)
            searchBox.borderColor = .color(.border, [.interactive, .strong])
        }
    }
}

extension CountriesSectionViewController: CountriesSettingsDelegate {
    func updateQuickSettings(secureCore: Bool, netshield: NetShieldType, killSwitch: Bool, portForwarding: Bool) {
        secureCoreBtn.switchState(secureCore ? AppTheme.Icon.locks : AppTheme.Icon.lock, enabled: secureCore)
        killSwitchBtn.switchState(killSwitch ? AppTheme.Icon.switchOn : AppTheme.Icon.switchOff, enabled: killSwitch)
        netShieldBtn.switchState(netshield == .off ? AppTheme.Icon.shield : (netshield == .level1 ? AppTheme.Icon.shieldHalfFilled : AppTheme.Icon.shieldFilled), enabled: netshield != .off)
        portForwardingBtn
            .switchState(portForwarding ? AppTheme.Icon.arrowsSwitch : AppTheme.Icon.arrowUpBounceLeft, enabled: portForwarding)
        quickSettingsManager.reloadAllOptions()
    }
}

extension CountriesSectionViewController: QuickSettingsManagerDelegate {
    func quickSettingsManager(_: QuickSettingsManager, didShowSetting _: QuickSettingType) {
        searchTextField.isEnabled = false

        // Set accessibility identifiers
        secureCoreBtn.setAccessibilityIdentifier("SecureCoreButton")
        netShieldBtn.setAccessibilityIdentifier("NetShieldButton")
        killSwitchBtn.setAccessibilityIdentifier("KillSwitchButton")
        portForwardingBtn.setAccessibilityIdentifier("PortForwardingButton")
    }

    func quickSettingsManagerDidHideAllSettings(_: QuickSettingsManager) {
        searchTextField.isEnabled = true
    }
}

extension CountriesSectionViewController {
    private enum Dimensions {
        static let quickSettingsHeight: CGFloat = 54
        static let quickSettingsTopOffset: CGFloat = 8
        static let quickSettingsHorizontalInset: CGFloat = 14
        static let searchBoxHeight: CGFloat = 46
        static let searchBoxHorizontalInset: CGFloat = 20
        static let separatorHeight: CGFloat = 1
        static let separatorTopOffset: CGFloat = 7
        static let searchIconSize: CGFloat = 16
        static let searchIconLeading: CGFloat = 8
        static let searchFieldLeading: CGFloat = 8
        static let clearButtonSize: CGFloat = 16
        static let clearButtonLeading: CGFloat = 8
        static let clearButtonTrailing: CGFloat = -16
        static let quickSettingButtonHeight: CGFloat = 38
        static let quickSettingButtonInset: CGFloat = 8
        static let quickSettingButtonCenterYOffset: CGFloat = -4
        static let netShieldBadgeMinWidth: CGFloat = 20
        static let netShieldBadgeHeight: CGFloat = 14
        static let netShieldBadgeCenterXOffset: CGFloat = 12
        static let netShieldBadgeCenterYOffset: CGFloat = -12
        static let netShieldBadgeFontSize: CGFloat = 10
        static let netShieldBadgeCornerRadius: CGFloat = 4
    }
}

class QuickSettingsStack: NSStackView {
    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityLabel() -> String? {
        Localizable.quickSettingsTitle
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .toolbar
    }
}
