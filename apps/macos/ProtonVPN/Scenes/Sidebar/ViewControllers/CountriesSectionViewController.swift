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

final class CountriesSectionViewController: NSViewController {
    @IBOutlet var searchIcon: NSImageView!
    @IBOutlet var searchTextField: TextFieldWithFocus!
    @IBOutlet var searchBox: NSBox!

    @IBOutlet var bottomHorizontalLine: NSBox!
    @IBOutlet var countriesListView: NSView!

    @IBOutlet var clearSearchBtn: NSButton!

    @IBOutlet var quickSettingsStack: QuickSettingsStack!
    @IBOutlet var secureCoreBox: NSBox!
    @IBOutlet var netShieldBox: NSBox!
    @IBOutlet var killSwitchBox: NSBox!
    @IBOutlet var portForwardingBox: NSBox!

    @IBOutlet var secureCoreBtn: QuickSettingButton!
    @IBOutlet var netShieldBtn: QuickSettingButton!
    @IBOutlet var killSwitchBtn: QuickSettingButton!
    @IBOutlet var portForwardingBtn: QuickSettingButton!

    @IBOutlet var netShieldStatsLabel: NSTextField?

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
        super.init(nibName: NSNib.Name("CountriesSection"), bundle: nil)
        viewModel.delegate = self
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
        netShieldStatsLabel?.layer?.cornerRadius = 4
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
