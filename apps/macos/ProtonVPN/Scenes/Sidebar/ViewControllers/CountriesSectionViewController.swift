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
import Strings
import Theme
import Home
import VPNShared
import LegacyCommon

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

        var identifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier(self.rawValue) }
        var nib: NSNib? { NSNib(nibNamed: NSNib.Name(self.rawValue), bundle: nil) }
    }
    
    enum QuickSettingType {
        case secureCoreDisplay
        case netShieldDisplay
        case killSwitchDisplay
    }

    @IBOutlet weak var searchIcon: NSImageView!
    @IBOutlet weak var searchTextField: TextFieldWithFocus!
    @IBOutlet weak var searchBox: NSBox!

    @IBOutlet weak var bottomHorizontalLine: NSBox!
    @IBOutlet weak var serverListScrollView: BlockableScrollView!
    @IBOutlet weak var serverListTableView: NSTableView!
    @IBOutlet weak var shadowView: ShadowView!
    @IBOutlet weak var clearSearchBtn: NSButton!
    
    @IBOutlet weak var quickSettingsStack: QuickSettingsStack!
    @IBOutlet weak var secureCoreSectionView: NSView!
    @IBOutlet weak var netShieldSectionView: NSView!
    @IBOutlet weak var killSwitchSectionView: NSView!
    
    @IBOutlet weak var netShieldBox: NSBox!
    
    @IBOutlet weak var secureCoreBtn: QuickSettingButton!
    @IBOutlet weak var netShieldBtn: QuickSettingButton!
    @IBOutlet weak var killSwitchBtn: QuickSettingButton!
    
    @IBOutlet weak var listTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var listLeadingConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var secureCoreContainer: NSBox!
    @IBOutlet weak var netshieldContainer: NSBox!
    @IBOutlet weak var killSwitchContainer: NSBox!
    @IBOutlet weak var netShieldStatsLabel: NSTextField?

    fileprivate let viewModel: CountriesSectionViewModel
    
    private var infoButtonRowSelected: Int?
    private var quickSettingDetailDisplayed = false
    
    weak var sidebarView: NSView?

    private var notificationTokens: [NotificationToken] = []
    
    required init?(coder: NSCoder) {
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

        secureCoreBtn.setAccessibilityChildren([secureCoreContainer as Any])
        netShieldBtn.setAccessibilityChildren([netshieldContainer as Any])
        killSwitchBtn.setAccessibilityChildren([killSwitchContainer as Any])
    }

    func setupNetShieldBadge() {
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
            self.updateBadge()
        }
    }

    func updateBadge() {
        guard let presenter = viewModel.netShieldPresenter as? NetshieldDropdownPresenter else { return }

        if presenter.appStateManager.displayState != .connected {
            netShieldStatsLabel?.isHidden = true
        } else {
            netShieldStatsLabel?.isHidden = false
        }

        updateStats(stats: presenter.netShieldStats)
        if presenter.netShieldPropertyProvider.netShieldType != .level2 {
            updateStats(stats: .init(trackers: 0, ads: 0, data: 0, enabled: false))
        }
    }

    func updateStats(stats: NetShieldModel) {
        netShieldStatsLabel?.isEnabled = stats.enabled
        let badge = (stats.adsCount + stats.trackersCount) >= 99 ? "99+" : "\(stats.adsCount + stats.trackersCount)"
        netShieldStatsLabel?.stringValue = badge
    }

    func addNetShieldObservers() {
        notificationTokens.append(NotificationCenter.default.addObserver(for: NetShieldStatsNotification.self,
                                                                         object: nil) { [weak self] stats in
            DispatchQueue.main.async {
                self?.updateBadge()
            }
        })
        let netShieldNotification = NetShieldPropertyProviderImplementation.netShieldNotification
        notificationTokens.append(NotificationCenter.default.addObserver(for: netShieldNotification,
                                                                         object: nil) { [weak self] level in
            DispatchQueue.main.async {
                if (level.object as? NetShieldType) != .level2 {
                    self?.updateStats(stats: .init(trackers: 0, ads: 0, data: 0, enabled: false))
                }
            }
        })
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        didDisplayQuickSetting(appear: false)
    }
    
    override func viewDidLayout() {
        netShieldBtn.layoutSubtreeIfNeeded()
        secureCoreBtn.layoutSubtreeIfNeeded()
        killSwitchBtn.layoutSubtreeIfNeeded()
    }
    
    private func setupView() {
        view.wantsLayer = true
    }

    var observer: Any?

    /// Appearance change doesn't get propagated normally, so we have to manually update the colors when user changes appearance
    func observeAppearance() {
        observer = NSApp.observe(\.effectiveAppearance, options: [.new, .old, .initial, .prior]) { [weak self] app, change in
            guard let newValue = change.newValue else { return }
            newValue.performAsCurrentDrawingAppearance {
                self?.setupColors()
            }
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
        [ (viewModel.secureCorePresenter, secureCoreContainer, secureCoreBtn, 0),
          (viewModel.netShieldPresenter, netshieldContainer, netShieldBtn, 1),
          (viewModel.killSwitchPresenter, killSwitchContainer, killSwitchBtn, 2) ].forEach { presenter, container, button, index in
            let vc = QuickSettingDetailViewController(presenter)
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
        netShieldBox.isHidden = !viewModel.isNetShieldEnabled
        viewModel.updateSettings()
    }
    
    @objc private func scrolled(_ notification: Notification) {
        shadowView.shadow(for: serverListScrollView.contentView.bounds.origin.y)
    }
    
    @objc private func clearSearch() {
        if searchTextField.stringValue.isEmpty { return }
        searchTextField.stringValue = ""
        clearSearchBtn.isHidden = true
        viewModel.filterContent(forQuery: "")
    }
    
    private func didTapSettingButton( _ index: Int ) {
        switch index {
        case 0:
            let finalValue = secureCoreContainer.isHidden
            didDisplayQuickSetting(.secureCoreDisplay, appear: finalValue)
        case 1:
            let finalValue = netshieldContainer.isHidden
            didDisplayQuickSetting(.netShieldDisplay, appear: finalValue)
        default:
            let finalValue = killSwitchContainer.isHidden
            didDisplayQuickSetting(.killSwitchDisplay, appear: finalValue)
        }
    }
    
    private func didDisplayQuickSetting(_ quickSettingItem: QuickSettingType? = nil, appear: Bool ) {
        
        let secureCoreDisplay = (quickSettingItem == .secureCoreDisplay) && appear
        let netShieldDisplay = (quickSettingItem == .netShieldDisplay) && appear
        let killSwitchDisplay = (quickSettingItem == .killSwitchDisplay) && appear
        
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
        
        serverListScrollView.block = appear
        quickSettingDetailDisplayed = appear
        
        secureCoreBtn.setAccessibilityIdentifier("SecureCoreButton")
        netShieldBtn.setAccessibilityIdentifier("NetShieldButton")
        killSwitchBtn.setAccessibilityIdentifier("KillSwitchButton")

        serverListTableView.reloadData()
    }

    private func contentChanged(_ contentChange: ContentChange) {
        
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
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.cellCount
    }
}

extension CountriesSectionViewController: NSTableViewDelegate {

    // todo: would be better to change this to autosize, because banners may have different heights
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch viewModel.cellModel(forRow: row) {
        case .country:
            return 48
        case .header:
            return 32
        case .banner:
            return 100
        case .offerBanner(let model):
            return model.showCountdown ? 128 : 113
        default:
            return 40
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cellWrapper = viewModel.cellModel(forRow: row) else {
            log.error("Countries section failed to load cell for row \(row).", category: .ui)
            return nil
        }
        
        switch cellWrapper {
        case .country(let model):
            let cell = tableView.makeView(withIdentifier: Cell.country.identifier, owner: self) as! CountryItemCellView
            cell.disabled = quickSettingDetailDisplayed
            cell.updateView(withModel: model)
            return cell
        case .server(let model):
            let cell = tableView.makeView(withIdentifier: Cell.server.identifier, owner: self) as! ServerItemCellView
            cell.disabled = quickSettingDetailDisplayed
            cell.updateView(withModel: model)
            cell.delegate = self
            return cell
        case .header(let model):
            let cell = tableView.makeView(withIdentifier: Cell.header.identifier, owner: self) as! CountriesSectionHeaderView
            cell.configure(with: model)
            return cell
        case .profile(let profileModel):
            let cell = tableView.makeView(withIdentifier: Cell.profile.identifier, owner: nil) as! ProfileItemView
            cell.updateView(withModel: profileModel, hideSeparator: true)
            return cell
        case .banner(let viewModel):
            let cell = tableView.makeView(withIdentifier: Cell.banner.identifier, owner: nil) as! BannerCellView
            cell.updateView(withModel: viewModel)
            return cell
        case .offerBanner(let viewModel):
            let cell = tableView.makeView(withIdentifier: Cell.offerBanner.identifier, owner: nil) as! OfferBannerView
            cell.updateView(withModel: viewModel)
            return cell
        }
    }
}

extension CountriesSectionViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        clearSearchBtn.isHidden = searchTextField.stringValue.isEmpty
        viewModel.filterContent(forQuery: searchTextField.stringValue)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            searchIcon.image = searchIcon.image?.colored(.weak)
            searchBox.borderColor = .color(.border)
        }
    }
}

extension CountriesSectionViewController: TextFieldFocusDelegate {
    /// Don't focus on search field when countries view is displayed
    var shouldBecomeFirstResponder: Bool { false }

    func willReceiveFocus(_ textField: NSTextField) {
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            searchIcon.image = searchIcon.image?.colored(.normal)
            searchBox.borderColor = .color(.border, [.interactive, .strong])
        }
    }
}

extension CountriesSectionViewController: CountriesSettingsDelegate {
    func updateQuickSettings(secureCore: Bool, netshield: NetShieldType, killSwitch: Bool) {
        secureCoreBtn.switchState(secureCore ? AppTheme.Icon.locks : AppTheme.Icon.lock, enabled: secureCore)
        killSwitchBtn.switchState(killSwitch ? AppTheme.Icon.switchOn : AppTheme.Icon.switchOff, enabled: killSwitch)
        netShieldBtn.switchState(netshield == .off ? AppTheme.Icon.shield : (netshield == .level1 ? AppTheme.Icon.shieldHalfFilled : AppTheme.Icon.shieldFilled), enabled: netshield != .off)
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
