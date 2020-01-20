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

import Cocoa
import vpncore

class CountriesSectionViewController: NSViewController {

    fileprivate struct CellIdentifier {
        static let country = "Country"
        static let server = "Server"
        static let secureCoreServer = "SecureCoreServer"
    }
    
    @IBOutlet weak var secureCoreSwitch: SwitchButton!
    @IBOutlet weak var secureCoreLabel: NSTextField!
    @IBOutlet weak var secureCoreInfoIcon: NSImageView!
    @IBOutlet weak var topHorizontalLine: NSBox!
    @IBOutlet weak var searchIcon: NSImageView!
    @IBOutlet weak var searchTextField: TextFieldWithFocus!
    @IBOutlet weak var bottomHorizontalLine: NSBox!
    @IBOutlet weak var serverListScrollView: NSScrollView!
    @IBOutlet weak var serverListTableView: NSTableView!
    @IBOutlet weak var shadowView: ShadowView!
    
    fileprivate let viewModel: CountriesSectionViewModel
    
    private var infoButtonRowSelected: Int?
    private var serverInfoViewController: ServerInfoViewController?
    
    weak var sidebarView: NSView?
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: CountriesSectionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("CountriesSection"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupHeaderSection()
        setupSearchSection()
        setupTableView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupHeaderSection() {
        secureCoreSwitch.drawsUnderOverlay = true
        secureCoreSwitch.registerDelegate(self)
        secureCoreSwitch.setState(viewModel.secureCoreState, animated: false)
        secureCoreSwitch.setAccessibilityLabel(LocalizedString.secureCore)
        secureCoreSwitch.setAccessibilityElement(true)
        secureCoreSwitch.setAccessibilityRole(.button)
        secureCoreSwitch.setAccessibilityHelp(LocalizedString.secureCoreInfo)
        
        setSecureCoreLabel()
        
        secureCoreInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        secureCoreInfoIcon.toolTip = LocalizedString.secureCoreInfo
    }
    
    private func setupSearchSection() {
        topHorizontalLine.fillColor = .protonLightGrey()
        bottomHorizontalLine.fillColor = .protonLightGrey()
        
        searchIcon.image = NSImage(named: NSImage.Name("search"))
        
        searchTextField.delegate = self
        searchTextField.usesSingleLineMode = true
        searchTextField.focusRingType = .none
        searchTextField.refusesFirstResponder = true
        searchTextField.textColor = .protonWhite()
        searchTextField.font = NSFont.systemFont(ofSize: 16)
        searchTextField.alignment = .left
        searchTextField.placeholderAttributedString = LocalizedString.searchForCountry.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .left)
    }
    
    private func setupTableView() {
        serverListTableView.dataSource = self
        serverListTableView.delegate = self
        serverListTableView.ignoresMultiClick = true
        serverListTableView.selectionHighlightStyle = .none
        serverListTableView.intercellSpacing = NSSize(width: 0, height: 0)
        serverListTableView.backgroundColor = .protonGrey()
        serverListTableView.register(NSNib(nibNamed: NSNib.Name("CountryItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.country))
        serverListTableView.register(NSNib(nibNamed: NSNib.Name("ServerItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.server))
        serverListTableView.register(NSNib(nibNamed: NSNib.Name("SecureCoreServerItem"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.secureCoreServer))
        
        serverListScrollView.backgroundColor = .protonGrey()
        shadowView.shadow(for: serverListScrollView.contentView.bounds.origin.y)
        serverListScrollView.contentView.postsBoundsChangedNotifications = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled(_:)), name: NSView.boundsDidChangeNotification, object: serverListScrollView.contentView)
        viewModel.contentChanged = { [unowned self] change in self.contentChanged(change) }
        viewModel.disconnectWarning = { [unowned self] viewModel in self.disconnectWarning(viewModel) }
        viewModel.secureCoreChange = { [unowned self] enabled in self.secureCoreSwitchChanged(enabled) }
    }
    
    private func setSecureCoreLabel() {
        secureCoreLabel.attributedStringValue = LocalizedString.secureCore.attributed(withColor: secureCoreSwitch.currentButtonState == .on ? .protonWhite() : .protonGreyOutOfFocus(),
                                                                                   fontSize: 16,
                                                                                       bold: true,
                                                                                  alignment: .left)
    }
    
    private func showInfo(for row: Int, and view: NSView, with server: ServerModel) {
        guard let sidebarView = sidebarView else { return }
        
        let infoModel = ServerInfoViewModel(server: server)
        if let infoButtonRowSelected = infoButtonRowSelected,
           let serverInfoViewController = serverInfoViewController,
           sidebarView.subviews.contains(serverInfoViewController.view) {
            serverInfoViewController.removeFromParent()
            guard infoButtonRowSelected != row else {
                self.serverInfoViewController = nil
                return
            }
        }
        infoButtonRowSelected = row
        serverInfoViewController = ServerInfoViewController(viewModel: infoModel)
        
        let rowOrigin = self.view.convert(view.frame.origin, from: view)
        serverInfoViewController!.infoYPosition = rowOrigin.y + view.frame.height / 2
        serverInfoViewController!.view.frame = sidebarView.frame
        sidebarView.addSubview(serverInfoViewController!.view)
    }
    
    @objc private func scrolled(_ notification: Notification) {
        shadowView.shadow(for: serverListScrollView.contentView.bounds.origin.y)
    }
    
    // swiftlint:disable cyclomatic_complexity
    private func contentChanged(_ contentChange: ContentChange) {
        // Update content of currently visible rows
        serverListTableView.enumerateAvailableRowViews { (rowView, row) in
            if let cellWrapper = viewModel.cellModel(forRow: row) {
                switch cellWrapper {
                case .server(let model):
                    if let serverView = rowView.subviews[0] as? ServerItemView {
                        serverView.updateView(withModel: model)
                        serverView.showServerInfo = { [weak self] in
                            guard let `self` = self else { return }
                            self.showInfo(for: row, and: serverView, with: model.serverModel)
                        }
                        if let infoButtonRow = infoButtonRowSelected, infoButtonRow == row, let serverInfoViewController = serverInfoViewController {
                            serverInfoViewController.updateView(with: ServerInfoViewModel(server: model.serverModel))
                        }
                    }
                case .secureCoreServer(let model):
                    if let serverView = rowView.subviews[0] as? SecureCoreServerItemView {
                        serverView.updateView(withModel: model)
                        serverView.showServerInfo = { [weak self] in
                            guard let `self` = self else { return }
                            self.showInfo(for: row, and: serverView, with: model.serverModel)
                        }
                        if let infoButtonRow = infoButtonRowSelected, infoButtonRow == row, let serverInfoViewController = serverInfoViewController {
                            serverInfoViewController.updateView(with: ServerInfoViewModel(server: model.serverModel))
                        }
                    }
                default:
                    break
                }
            }
        }
        // swiftlint:enable cyclomatic_complexity
        
        let shouldAnimate = contentChange.insertedRows == nil || contentChange.removedRows == nil
        
        serverListTableView.beginUpdates()
        if let removedRows = contentChange.removedRows {
            serverListTableView.removeRows(at: removedRows, withAnimation: shouldAnimate ? [NSTableView.AnimationOptions.slideUp] : [])
        }
        
        if let insertedRows = contentChange.insertedRows {
            serverListTableView.insertRows(at: insertedRows, withAnimation: shouldAnimate ? [NSTableView.AnimationOptions.slideDown] : [])
        }
        serverListTableView.endUpdates()
        
        if contentChange.reset {
            serverListTableView.scrollRowToVisible(0)
        }
    }
    
    private func disconnectWarning(_ viewModel: WarningPopupViewModel) {
        secureCoreSwitch.setState(ButtonState(rawValue: 1 - secureCoreSwitch.currentButtonState.rawValue)!)
        presentAsModalWindow(WarningPopupViewController(viewModel: viewModel))
    }
    
    private func secureCoreSwitchChanged(_ enabled: Bool) {
        secureCoreSwitch.setState(enabled ? .on : .off)
    }
}

extension CountriesSectionViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.cellCount
    }
}

extension CountriesSectionViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return viewModel.cellHeight
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cellWrapper = viewModel.cellModel(forRow: row) else {
            PMLog.D("Countries section failed to load cell for row \(row).", level: .error)
            return nil
        }
        
        switch cellWrapper {
        case .country(let model):
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.country), owner: self) as! CountryItemView
            cell.updateView(withModel: model)
            cell.rowSeparator.isHidden = row == 0
            return cell
        case .server(let model):
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.server), owner: self) as! ServerItemView
            cell.updateView(withModel: model)
            cell.showServerInfo = { [weak self] in
                guard let `self` = self else { return }
                self.showInfo(for: row, and: cell, with: model.serverModel)
            }
            return cell
        case .secureCoreCountry(let model):
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.country), owner: self) as! CountryItemView
            cell.updateView(withModel: model)
            cell.rowSeparator.isHidden = row == 0
            return cell
        case .secureCoreServer(let model):
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifier.secureCoreServer), owner: self) as! SecureCoreServerItemView
            cell.updateView(withModel: model)
            cell.showServerInfo = { [weak self] in
                guard let `self` = self else { return }
                self.showInfo(for: row, and: cell, with: model.serverModel)
            }
            return cell
        }
    }
}

extension CountriesSectionViewController: SwitchButtonDelegate {
    
    func switchButtonClicked(_ button: NSButton) {
        viewModel.toggleStateAction()
        setSecureCoreLabel()
    }
}

extension CountriesSectionViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        viewModel.filterContent(forQuery: searchTextField.stringValue)
    }
}
