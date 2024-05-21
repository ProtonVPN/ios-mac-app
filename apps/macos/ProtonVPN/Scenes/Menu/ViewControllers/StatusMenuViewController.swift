//
//  StatusMenuViewController.swift
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
import Ergonomics
import LegacyCommon

protocol StatusMenuViewControllerProtocol: AnyObject {
    var secureCoreSwitch: SwitchButton! { get }
}

class StatusMenuViewController: NSViewController, StatusMenuViewControllerProtocol {
    
    private static let countryCollectionItemIdentifier = NSUserInterfaceItemIdentifier("CountryItem")
    
    let viewModel: StatusMenuViewModel
    
    @IBOutlet private weak var backgroundView: NSView!
    @IBOutlet private weak var dynamicContentView: NSStackView!
    @IBOutlet private weak var loginLabel: NSTextField!
    @IBOutlet private weak var upgradeView: NSStackView!
    @IBOutlet private weak var upgradeLabel: NSTextField!
    
    @IBOutlet private weak var connectionLabel: NSTextField!
    @IBOutlet private weak var ipLabel: NSTextField!
    @IBOutlet private weak var connectButton: StatusBarAppConnectButton!
    @IBOutlet private weak var profileDropDown: StatusBarAppProfileDropdownButton!
    @IBOutlet private weak var changeServerView: ChangeServerView!
    
    @IBOutlet weak var secureCoreSwitch: SwitchButton!
    @IBOutlet private weak var secureCoreLabel: NSTextField!
    
    @IBOutlet private weak var countryScrollView: NSScrollView!
    @IBOutlet private weak var countryClipView: NSClipView!
    @IBOutlet private weak var countryCollection: NSCollectionView!
    
    @IBOutlet private weak var quitButton: NSButton!
    @IBOutlet private weak var showProtonVPNButton: NSButton!

    @IBOutlet private weak var loadingViewContainer: NSView!
    @IBOutlet private weak var loadingView: LoadingAnimationView!
    @IBOutlet private weak var loadingLabel: NSTextField!
    @IBOutlet private weak var cancelConnectionButton: ConnectingOverlayButton!

    @IBOutlet private weak var footerView: NSView!
    
    private var profilesWindowController: StatusMenuProfilesListController?
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(with viewModel: StatusMenuViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("StatusMenu"), bundle: nil)
        
        viewModel.contentChanged = { [weak self] in
            self?.contentChanged()
        }

        viewModel.changeServerStateChanged = { [weak self] _ in
            self?.setupHeaderButtons()
        }
        
        viewModel.disconnectWarning = { [weak self] viewModel in
            self?.disconnectWarning(viewModel)
        }

        viewModel.unsecureWiFiWarning = { [weak self] viewModel in
            self?.unsecureWarning(viewModel)
        }
        
        viewModel.viewController = self
        initialViewSetup()
    }
    
    override func viewDidLoad() {
        setupBackgroundColor()
        setupSecureCoreSection()
        setupCountryCollection()
        super.viewDidLoad()
    }
    
    override func viewDidDisappear() {
        hideProfilesList()
    }
    
    private func initialViewSetup() {        
        view.wantsLayer = true
        
        if let visualEffectView = view as? ClickDetectingVisualEffectView {
            visualEffectView.clickAction = { [weak self] in
                guard let self = self else {
                    return
                }

                guard let window = self.view.window, let profilesWindow = self.profilesWindowController?.window else {
                    return
                }
                
                if let contains = window.childWindows?.contains(profilesWindow), contains {
                    self.hideProfilesList()
                }
            }
        }
        
        loginLabel.attributedStringValue = viewModel.loginDescription
                
        let upgradeText = NSMutableAttributedString()
        upgradeText.append(viewModel.upgradeToPlusTitle)
        upgradeText.append(viewModel.upgradeForSecureCoreLabel)
        upgradeLabel.attributedStringValue = upgradeText
        upgradeLabel.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(upgrade)))
        changeServerView.handler = viewModel.changeServerAction
        
        updateViewLayout()
    }

    private func setupBackgroundColor() {
        DarkAppearance {
            dynamicContentView.wantsLayer = true
            dynamicContentView.layer?.backgroundColor = .cgColor(.background)
            footerView.wantsLayer = true
            footerView.layer?.backgroundColor = .cgColor(.background)
            backgroundView.wantsLayer = true
            backgroundView.layer?.backgroundColor = .cgColor(.background)
        }
    }
        
    private func setupSecureCoreSection() {
        secureCoreSwitch.drawsUnderOverlay = true
        DarkAppearance {
            secureCoreSwitch.maskColor = .cgColor(.background)
        }
        secureCoreSwitch.registerDelegate(self)
        secureCoreSwitch.setState(.off)
        
        secureCoreLabel.attributedStringValue = viewModel.secureCoreLabel
    }
    
    private func setupCountryCollection() {
        countryClipView.postsBoundsChangedNotifications = true
        countryScrollView.backgroundColor = .color(.background, .transparent)
        NotificationCenter.default.addObserver(self, selector: #selector(countriesScrolled), name: NSView.boundsDidChangeNotification, object: countryClipView)
        
        let nib = NSNib(nibNamed: NSNib.Name("StatusMenuCountryViewItem"), bundle: nil)
        countryCollection.register(nib, forItemWithIdentifier: StatusMenuViewController.countryCollectionItemIdentifier)
        
        countryCollection.dataSource = self
        
        let horizontalSpacing: CGFloat = 8
        let verticalSpacing: CGFloat = 1
        let horizontalMargin: CGFloat = 16
        let verticalMargin: CGFloat = 12
        let itemWidthMin: CGFloat = 56
        let itemWidthMax: CGFloat = 65
        let itemHeight: CGFloat = 56
        
        let layout = NSCollectionViewGridLayout()
        layout.minimumItemSize = CGSize(width: itemWidthMin, height: itemHeight)
        layout.maximumItemSize = CGSize(width: itemWidthMax, height: itemHeight)
        layout.minimumInteritemSpacing = horizontalSpacing
        layout.minimumLineSpacing = verticalSpacing
        layout.margins = NSEdgeInsets(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin)
        countryCollection.collectionViewLayout = layout
    }
    
    private func showProfileList() {
        guard let window = view.window, let profilesWindow = profilesWindowController?.window else { return }
        
        connectButton.dropDownExpanded = true
        profileDropDown.dropDownExpanded = true
        
        window.addChildWindow(profilesWindow, ordered: .above)
        let connectFrameInWindow = connectButton.convert(connectButton.bounds, to: nil)
        let tableHeight: CGFloat = 200
        let menuButtonMargin: CGFloat = 5
        let profilesWindowFrame = CGRect(x: window.frame.minX + connectButton.frame.minX, y: window.frame.minY + connectFrameInWindow.minY + 2 - tableHeight - menuButtonMargin, width: window.frame.width - connectButton.frame.minX * 2, height: tableHeight)
        profilesWindowController?.window?.setFrame(profilesWindowFrame, display: true)
        profilesWindowController?.window?.makeKeyAndOrderFront(self)
    }
    
    private func hideProfilesList() {
        guard let window = view.window, let profilesWindow = profilesWindowController?.window else { return }
        
        window.removeChildWindow(profilesWindow)
        profilesWindowController?.close()
        profilesWindowController = nil
        
        connectButton.dropDownExpanded = false
        profileDropDown.dropDownExpanded = false
    }
    
    private func updateViewLayout() {
        
        if viewModel.isSessionEstablished {
            dynamicContentView.isHidden = viewModel.isConnecting
            
            loadingViewContainer.isHidden = !viewModel.isConnecting
            loadingView.animate(viewModel.isConnecting)
            loadingLabel.attributedStringValue = viewModel.connectingText
            if !viewModel.cancelButtonTitle.isEmpty {
                cancelConnectionButton.title = viewModel.cancelButtonTitle
                cancelConnectionButton.isHidden = false
            } else {
                cancelConnectionButton.isHidden = true
            }
            
            if viewModel.isConnecting {
                hideProfilesList()
            }
            loginLabel.isHidden = true

            if !viewModel.isConnecting && viewModel.serverType == .secureCore && viewModel.countryCount() == 0 {
                upgradeView.isHidden = false
            } else {
                upgradeView.isHidden = true
            }

            self.setupHeaderButtons()
        } else {
            dynamicContentView.isHidden = true
            loadingViewContainer.isHidden = true
            loadingView.animate(false)
            hideProfilesList()
            loginLabel.isHidden = false
            upgradeView.isHidden = true
        }
    }
    
    private func contentChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.connectionLabel.attributedStringValue = self.viewModel.connectionLabel
            self.ipLabel.attributedStringValue = self.viewModel.ipAddress

            self.updateViewLayout()
            setupHeaderButtons()

            self.secureCoreSwitch.setState(self.viewModel.serverType == .secureCore ? .on : .off)
            
            self.countryCollection.reloadData()
        }
    }

    private func setupHeaderButtons() {
        profileDropDown.isHidden = !self.viewModel.shouldShowProfileDropdown
        changeServerView.isHidden = !self.viewModel.shouldShowChangeServer

        self.connectButton.isConnected = self.viewModel.isConnected
        self.profileDropDown.isConnected = self.viewModel.isConnected
        self.changeServerView.state = .from(state: viewModel.canChangeServer)
    }
    
    @objc private func countriesScrolled() {
        countryCollection.visibleItems().forEach { item in
            if let countryItem = item as? StatusMenuCountryViewItem {
                countryItem.button.updateTrackingAreas()
            }
        }
    }

    private func unsecureWarning(_ viewModel: WarningPopupViewModel) {
        // This warning lies! "Cast from 'NSWindowDelegate?' to unrelated type 'WiFiWarningPopupViewController' always fails"
        if let window = NSApplication.shared.modalWindow, window.delegate is WiFiWarningPopupViewController {
            return
        }
        presentAsModalWindow(WiFiWarningPopupViewController(viewModel: viewModel))
    }
    
    private func disconnectWarning(_ viewModel: WarningPopupViewModel) {
        secureCoreSwitch.setState(ButtonState(rawValue: 1 - secureCoreSwitch.currentButtonState.rawValue)!)
        presentAsModalWindow(WarningPopupViewController(viewModel: viewModel))
    }
    
    @IBAction func connect(_ sender: Any) {
        viewModel.quickConnectAction()
    }
    
    @IBAction func cancelConnection(_ sender: Any) {
        viewModel.disconnectAction()
    }
    
    @IBAction func toggleProfilesList(_ sender: Any) {
        if profilesWindowController == nil {
            self.profilesWindowController = StatusMenuProfilesListController(windowNibName: NSNib.Name("StatusMenuProfilesList"), viewModel: viewModel.profileListViewModel)
        }
        
        guard let window = view.window, let profilesWindow = profilesWindowController?.window else { return }
        
        if let childWindows = window.childWindows, childWindows.contains(profilesWindow) {
            hideProfilesList()
        } else {
            showProfileList()
        }
    }
    
    @IBAction func upgrade(_ sender: Any) {
        viewModel.upgradeAction()
    }
    
    @IBAction func quit(_ sender: Any) {
        viewModel.quitApplicationAction()
    }
    
    @IBAction func showProtonVPN(_ sender: Any) {
        viewModel.showApplicationAction()
    }
}

extension StatusMenuViewController: SwitchButtonDelegate {
    
    func switchButtonClicked(_ button: NSButton) {
        viewModel.toggleSecureCore(secureCoreSwitch.currentButtonState)
    }
}

extension StatusMenuViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.countryCount()
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: StatusMenuViewController.countryCollectionItemIdentifier, for: indexPath)
        
        if let countryItem = item as? StatusMenuCountryViewItem, let updatedViewModel = viewModel.countryViewModel(at: indexPath) {
            countryItem.update(viewModel: updatedViewModel)
        }
        
        return item
    }
}
