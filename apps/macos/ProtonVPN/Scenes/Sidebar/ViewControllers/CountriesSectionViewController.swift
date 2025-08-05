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

import Domain
import Ergonomics
import LegacyCommon
import NetShield
import Strings
import Theme
import VPNShared

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
    fileprivate enum Cell: String, CaseIterable {
        case country = "CountryItemCellView"
        case server = "ServerItemCellView"
        case header = "CountriesSectionHeaderView"
        case profile = "ProfileItemView"
        case banner = "BannerCellView"
        case offerBanner = "OfferBannerView"

        var identifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier(rawValue) }
        var nib: NSNib? { NSNib(nibNamed: NSNib.Name(rawValue), bundle: nil) }
    }

    enum QuickSettingType {
        case secureCoreDisplay
        case netShieldDisplay
        case killSwitchDisplay
        case portForwardingDisplay
    }

    @IBOutlet var searchIcon: NSImageView!
    @IBOutlet var searchTextField: TextFieldWithFocus!
    @IBOutlet var searchBox: NSBox!

    @IBOutlet var bottomHorizontalLine: NSBox!
    @IBOutlet var serverListScrollView: BlockableScrollView!
    @IBOutlet var serverListTableView: NSTableView!
    @IBOutlet var shadowView: ShadowView!
    @IBOutlet var clearSearchBtn: NSButton!

    @IBOutlet var quickSettingsStack: QuickSettingsStack!
    @IBOutlet var secureCoreSectionView: NSView!
    @IBOutlet var netShieldSectionView: NSView!
    @IBOutlet var killSwitchSectionView: NSView!
    @IBOutlet var portForwardingSectionView: NSView!

    @IBOutlet var netShieldBox: NSBox!

    @IBOutlet var secureCoreBtn: QuickSettingButton!
    @IBOutlet var netShieldBtn: QuickSettingButton!
    @IBOutlet var killSwitchBtn: QuickSettingButton!
    @IBOutlet var portForwardingBtn: QuickSettingButton!

    @IBOutlet var listTrailingConstraint: NSLayoutConstraint!
    @IBOutlet var listLeadingConstraint: NSLayoutConstraint!

    @IBOutlet var secureCoreContainer: NSBox!
    @IBOutlet var netshieldContainer: NSBox!
    @IBOutlet var killSwitchContainer: NSBox!
    @IBOutlet var portForwardingContainer: NSBox!
    @IBOutlet var netShieldStatsLabel: NSTextField?
    @IBOutlet var portForwardingWarningImage: NSImageView!

    fileprivate let viewModel: CountriesSectionViewModel

    private var infoButtonRowSelected: Int?
    private var quickSettingDetailDisplayed = false

    private var quickSettingDetailPFViewController: QuickSettingDetailPFViewController?

    weak var sidebarView: NSView?

    private var notificationTokens: [NotificationToken] = []

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
        setupPortForwardingAlertBage()
        observeAppearance()

        secureCoreBtn.setAccessibilityChildren([secureCoreContainer as Any])
        netShieldBtn.setAccessibilityChildren([netshieldContainer as Any])
        killSwitchBtn.setAccessibilityChildren([killSwitchContainer as Any])
        portForwardingBtn.setAccessibilityChildren([portForwardingContainer as Any])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        didDisplayQuickSetting(appear: false)
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

        serverListTableView.backgroundColor = .color(.background, .weak)
        serverListScrollView.backgroundColor = .color(.background, .weak)

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
        serverListTableView.dataSource = self
        serverListTableView.delegate = self
        serverListTableView.ignoresMultiClick = true
        serverListTableView.selectionHighlightStyle = .none
        serverListTableView.intercellSpacing = NSSize(width: 0, height: 0)
        serverListTableView.backgroundColor = .color(.background, .weak)
        serverListTableView.setAccessibilityIdentifier("ServerListTable")
        Cell.allCases.forEach { serverListTableView.register($0.nib, forIdentifier: $0.identifier) }

        serverListScrollView.backgroundColor = .color(.background, .weak)
        shadowView.shadow(for: serverListScrollView.contentView.bounds.origin.y)
        serverListScrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self, selector: #selector(scrolled(_:)), name: NSView.boundsDidChangeNotification, object: serverListScrollView.contentView)
        viewModel.contentChanged = { [weak self] change in self?.contentChanged(change) }
        viewModel.displayPremiumServices = { [weak self] in
            self?.presentAsSheet(FeaturesOverlayViewController(viewModel: PremiumFeaturesOverlayViewModel()))
        }
        viewModel.displayStreamingServices = { [weak self] in
            self?.presentAsSheet(StreamingServicesOverlayViewController(viewModel: StreamingServicesOverlayViewModel(country: $0, streamServices: $1, propertiesManager: $2)))
        }
        viewModel.displayGatewaysServices = { [weak self] in
            self?.presentAsSheet(FeaturesOverlayViewController(viewModel: GatewayFeaturesOverlayViewModel()))
        }
    }

    private func setupQuickSettings() {
        [
            (viewModel.secureCorePresenter, secureCoreContainer, secureCoreBtn, 0),
            (viewModel.netShieldPresenter, netshieldContainer, netShieldBtn, 1),
            (viewModel.killSwitchPresenter, killSwitchContainer, killSwitchBtn, 2),
            (viewModel.portForwardingPresenter, portForwardingContainer, portForwardingBtn, 3),
        ].forEach { presenter, container, button, index in
            let vc: QuickSettingDetailViewController
            switch index {
            case 1:
                vc = QuickSettingDetailNetShieldViewController(presenter)
            case 3:
                let pfVC = QuickSettingDetailPFViewController(presenter)
                self.quickSettingDetailPFViewController = pfVC
                vc = pfVC
            default:
                vc = QuickSettingDetailViewController(presenter)
            }
            vc.viewWillAppear()
            container?.addSubview(vc.view)
            container?.heightAnchor.constraint(equalTo: vc.view.heightAnchor).isActive = true
            container?.widthAnchor.constraint(equalTo: vc.view.widthAnchor).isActive = true
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            button?.toolTip = presenter.title
            button?.callback = { [weak self] _ in self?.didTapSettingButton(index) }
            button?.detailOpened = false
            presenter.dismiss = { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.didDisplayQuickSetting(appear: false)
                }
            }
            self.addChild(vc)
        }
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
        if presenter.netShieldPropertyProvider.netShieldType != .level2 {
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

        notificationTokens.append(NotificationCenter.default.addObserver(
            for: AppEvent.netShield.name,
            object: nil
        ) { [weak self] level in
            DispatchQueue.main.async {
                if (level.object as? NetShieldType) != .level2 {
                    self?.updateStats(stats: .zero(enabled: false))
                }
            }
        })
    }

    // MARK: - Port forwarding alert badge

    private func setupPortForwardingAlertBage() {
        portForwardingWarningImage?.wantsLayer = true
        portForwardingWarningImage?.contentTintColor = .color(.icon, .warning)

        DispatchQueue.main.async {
            self.updatePortForwardingAlertBage()
        }
    }

    private func updatePortForwardingAlertBage() {
        if viewModel.isConnected, viewModel.portForwardingIsOn, !viewModel.connectedServerSupportsP2P {
            portForwardingWarningImage?.image = AppTheme.Icon.exclamationTriangleFilled
            portForwardingWarningImage?.isHidden = false
        } else {
            portForwardingWarningImage?.isHidden = true
        }
    }

    private func updatePortForwardingView() {
        switch (viewModel.isConnected, viewModel.portForwardingIsOn, viewModel.connectedServerSupportsP2P) {
        case (true, true, true):
            quickSettingDetailPFViewController?.updatePortForwardingContainer(with: .connectedToP2P)
        case (true, true, false):
            quickSettingDetailPFViewController?.updatePortForwardingContainer(with: .connectedNotToP2P)
        case (true, false, _):
            quickSettingDetailPFViewController?.updatePortForwardingContainer(with: .connectedNoPf)
        case (false, true, _):
            quickSettingDetailPFViewController?.updatePortForwardingContainer(with: .notConnected(pfEnabled: true))
        case (false, false, _):
            quickSettingDetailPFViewController?.updatePortForwardingContainer(with: .notConnected(pfEnabled: false))
        }
    }

    @objc
    private func scrolled(_: Notification) {
        shadowView.shadow(for: serverListScrollView.contentView.bounds.origin.y)
    }

    @objc
    private func clearSearch() {
        if searchTextField.stringValue.isEmpty { return }
        searchTextField.stringValue = ""
        clearSearchBtn.isHidden = true
        viewModel.filterContent(forQuery: "")
    }

    private func didTapSettingButton(_ index: Int) {
        switch index {
        case 0:
            let finalValue = secureCoreContainer.isHidden
            didDisplayQuickSetting(.secureCoreDisplay, appear: finalValue)
        case 1:
            let finalValue = netshieldContainer.isHidden
            didDisplayQuickSetting(.netShieldDisplay, appear: finalValue)
        case 2:
            let finalValue = killSwitchContainer.isHidden
            didDisplayQuickSetting(.killSwitchDisplay, appear: finalValue)
        case 3:
            let finalValue = portForwardingContainer.isHidden
            didDisplayQuickSetting(.portForwardingDisplay, appear: finalValue)
        default:
            return
        }
    }

    private func didDisplayQuickSetting(_ quickSettingItem: QuickSettingType? = nil, appear: Bool) {
        let secureCoreDisplay = (quickSettingItem == .secureCoreDisplay) && appear
        let netShieldDisplay = (quickSettingItem == .netShieldDisplay) && appear
        let killSwitchDisplay = (quickSettingItem == .killSwitchDisplay) && appear
        let portForwardingDisplay = (quickSettingItem == .portForwardingDisplay) && appear

        searchTextField.isEnabled = !appear

        secureCoreBtn.detailOpened = secureCoreDisplay
        secureCoreContainer.isHidden = !secureCoreDisplay

        netShieldBtn.detailOpened = netShieldDisplay
        netshieldContainer.isHidden = !netShieldDisplay

        let expectedHeight = 784.0 // determined experimentally, not worth finding a "right" solution given the imminent changes

        if netShieldDisplay,
           let window = view.window,
           window.frame.height < expectedHeight {
            var newFrame = window.frame
            newFrame.size.height = expectedHeight
            newFrame.origin.y -= expectedHeight - window.frame.height // the window should gain size towards the bottom.
            view.window?.setFrame(newFrame, display: true)
        }

        killSwitchBtn.detailOpened = killSwitchDisplay
        killSwitchContainer.isHidden = !killSwitchDisplay

        portForwardingBtn.detailOpened = portForwardingDisplay
        portForwardingContainer.isHidden = !portForwardingDisplay

        serverListScrollView.block = appear
        quickSettingDetailDisplayed = appear

        secureCoreBtn.setAccessibilityIdentifier("SecureCoreButton")
        netShieldBtn.setAccessibilityIdentifier("NetShieldButton")
        killSwitchBtn.setAccessibilityIdentifier("KillSwitchButton")
        portForwardingBtn.setAccessibilityIdentifier("PortForwardingButton")

        serverListTableView.reloadData()
    }

    private func contentChanged(_ contentChange: ContentChange) {
        updatePortForwardingAlertBage()
        updatePortForwardingView()

        if contentChange.reset {
            serverListTableView.reloadData()
            return
        }

        if let indexes = contentChange.reload {
            serverListTableView.reloadData(forRowIndexes: indexes, columnIndexes: IndexSet([0]))
            return
        }

        let shouldAnimate = contentChange.insertedRows == nil || contentChange.removedRows == nil

        serverListTableView.beginUpdates()
        if let removedRows = contentChange.removedRows {
            serverListTableView.removeRows(at: removedRows, withAnimation: shouldAnimate ? [NSTableView.AnimationOptions.slideUp] : [])
        }

        if let insertedRows = contentChange.insertedRows {
            serverListTableView.insertRows(at: insertedRows, withAnimation: shouldAnimate ? [NSTableView.AnimationOptions.slideDown] : [])
        }
        serverListTableView.endUpdates()
    }
}

extension CountriesSectionViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        viewModel.cellCount
    }
}

extension CountriesSectionViewController: NSTableViewDelegate {
    // TODO: would be better to change this to autosize, because banners may have different heights
    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch viewModel.cellModel(forRow: row) {
        case .country:
            48
        case .header:
            32
        case .banner:
            100
        case let .offerBanner(model):
            model.showCountdown ? 128 : 113
        default:
            40
        }
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let cellWrapper = viewModel.cellModel(forRow: row) else {
            log.error("Countries section failed to load cell for row \(row).", category: .ui)
            return nil
        }

        switch cellWrapper {
        case let .country(model):
            let cell = tableView.makeView(withIdentifier: Cell.country.identifier, owner: self) as! CountryItemCellView
            cell.disabled = quickSettingDetailDisplayed
            cell.updateView(withModel: model)
            return cell
        case let .server(model):
            let cell = tableView.makeView(withIdentifier: Cell.server.identifier, owner: self) as! ServerItemCellView
            cell.disabled = quickSettingDetailDisplayed
            cell.updateView(withModel: model)
            cell.delegate = self
            return cell
        case let .header(model):
            let cell = tableView.makeView(withIdentifier: Cell.header.identifier, owner: self) as! CountriesSectionHeaderView
            cell.configure(with: model)
            return cell
        case let .profile(profileModel):
            let cell = tableView.makeView(withIdentifier: Cell.profile.identifier, owner: nil) as! ProfileItemView
            cell.updateView(withModel: profileModel, hideSeparator: true)
            return cell
        case let .banner(viewModel):
            let cell = tableView.makeView(withIdentifier: Cell.banner.identifier, owner: nil) as! BannerCellView
            cell.updateView(withModel: viewModel)
            return cell
        case let .offerBanner(viewModel):
            let cell = tableView.makeView(withIdentifier: Cell.offerBanner.identifier, owner: nil) as! OfferBannerView
            cell.updateView(withModel: viewModel)
            return cell
        }
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
        children
            .compactMap { $0 as? QuickSettingsDetailViewControllerProtocol }
            .forEach { $0.reloadOptions() }
    }
}

extension CountriesSectionViewController: ServerItemCellViewDelegate {
    func userDidRequestStreamingInfo(server: ServerItemViewModel) {
        viewModel.showStreamingServices(server: server)
    }
}
