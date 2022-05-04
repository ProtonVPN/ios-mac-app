//
//  CreateNewProfileViewController.swift
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

final class CreateNewProfileViewController: NSViewController {
    
    @IBOutlet private weak var profileSettingsLabel: PVPNTextField!
    @IBOutlet private weak var nameLabel: PVPNTextField!
    @IBOutlet private weak var nameTextField: TextFieldWithFocus!
    @IBOutlet private weak var nameTextFieldHorizontalLine: NSBox!
    @IBOutlet private weak var colorPickerLabel: PVPNTextField!
    @IBOutlet private weak var colorPickerViewContainer: NSView!
    
    @IBOutlet private weak var connectionSettingsLabel: PVPNTextField!
    @IBOutlet private weak var typeLabel: PVPNTextField!
    @IBOutlet private weak var typeList: HoverDetectionPopUpButton!
    @IBOutlet private weak var typeListHorizontalLine: NSBox!
    @IBOutlet private weak var countryLabel: PVPNTextField!
    @IBOutlet private weak var countryList: HoverDetectionPopUpButton!
    @IBOutlet private weak var countryListHorizontalLine: NSBox!
    @IBOutlet private weak var serverLabel: PVPNTextField!
    @IBOutlet private weak var serverList: HoverDetectionPopUpButton!
    @IBOutlet private weak var serverListHorizontalLine: NSBox!
    @IBOutlet private weak var protocolLabel: PVPNTextField!
    @IBOutlet private weak var protocolList: HoverDetectionPopUpButton!
    @IBOutlet private weak var protocolListHorizontalLine: NSBox!
    @IBOutlet private weak var protocolEnablementProgress: NSProgressIndicator!

    @IBOutlet private weak var warningLabel: PVPNTextField!
    @IBOutlet private weak var warningLabelHorizontalLine: NSBox!
    @IBOutlet private weak var footerView: NSView!
    @IBOutlet private weak var saveButton: PrimaryActionButton!
    @IBOutlet private weak var cancelButton: CancellationButton!
    
    fileprivate var viewModel: CreateNewProfileViewModel!

    private var colorPickerViewController: ColorPickerViewController!
    
    private var isSessionUnderway: Bool {
        return !nameTextField.stringValue.isEmpty ||
            typeList.indexOfSelectedItem != 0 ||
            countryList.indexOfSelectedItem != 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: CreateNewProfileViewModel) {
        super.init(nibName: NSNib.Name("CreateNewProfile"), bundle: nil)
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupHeaderView()
        setupNameSection()
        setupColorSection()
        setupTypeSection()
        setupCountrySection()
        setupServerSection()
        setupProtocolSection()
        setupWarningSection()
        setupFooterView()
        
        populateLists()
        startObserving()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        cancelButton.isHovered = false
        saveButton.isHovered = false
    }
    
    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = viewModel.cgColor(.background)
    }
    
    private func setupHeaderView() {
        profileSettingsLabel.attributedStringValue = viewModel.style(LocalizedString.profileSettings.uppercased(), context: .field, font: .themeFont(.small, bold: true), alignment: .left)
        connectionSettingsLabel.attributedStringValue = viewModel.style(LocalizedString.connectionSettings.uppercased(), context: .field, font: .themeFont(.small, bold: true), alignment: .left)
    }
    
    private func setupNameSection() {
        nameLabel.attributedStringValue = viewModel.style(LocalizedString.name + ":", font: .themeFont(.heading4), alignment: .left)

        nameTextField.style(placeholder: LocalizedString.name, font: .themeFont(.heading4), alignment: .left)
        nameTextField.drawsBackground = true
        nameTextField.focusRingType = .none
        nameTextField.delegate = self
        nameTextField.focusDelegate = self
        nameTextField.setAccessibilityIdentifier("NameTextField")
        
        nameTextFieldHorizontalLine.fillColor = viewModel.color(.border)
    }

    private func setupProtocolSection() {
        protocolLabel.attributedStringValue = viewModel.style(LocalizedString.vpnProtocol, font: .themeFont(.heading4), alignment: .left)

        protocolList.isBordered = false
        protocolList.menu?.delegate = self
        protocolList.target = self
        protocolList.action = #selector(protocolSelected)

        protocolEnablementProgress.isDisplayedWhenStopped = false
        protocolEnablementProgress.appearance = NSAppearance(named: .darkAqua)
        protocolEnablementProgress.toolTip = LocalizedString.sysexSettingsDescription

        protocolListHorizontalLine.fillColor = viewModel.color(.border)
    }
    
    private func setupColorSection() {
        colorPickerLabel.attributedStringValue = viewModel.style(LocalizedString.color + ":", font: .themeFont(.heading4), alignment: .left)
        
        colorPickerViewController = ColorPickerViewController(viewModel: viewModel.colorPickerViewModel)
        colorPickerViewContainer.pin(viewController: colorPickerViewController)
    }
    
    private func setupTypeSection() {
        typeLabel.attributedStringValue = viewModel.style(LocalizedString.feature + ":", font: .themeFont(.heading4), alignment: .left)
        
        typeList.isBordered = false
        typeList.menu?.delegate = self
        typeList.target = self
        typeList.action = #selector(typeSelected)
        
        typeListHorizontalLine.fillColor = viewModel.color(.border)
    }
    
    private func setupCountrySection() {
        countryLabel.attributedStringValue = viewModel.style(LocalizedString.country + ":", font: .themeFont(.heading4), alignment: .left)
        
        countryList.isBordered = false
        countryList.menu?.delegate = self
        countryList.target = self
        countryList.action = #selector(countrySelected)
        countryList.setAccessibilityIdentifier("CountryList")

        countryListHorizontalLine.fillColor = viewModel.color(.border)
    }
    
    private func setupServerSection() {
        serverLabel.attributedStringValue = viewModel.style(LocalizedString.server + ":", font: .themeFont(.heading4), alignment: .left)
        
        serverList.isBordered = false
        serverList.menu?.delegate = self
        serverList.target = self
        serverList.action = #selector(serverSelected)
        serverList.setAccessibilityIdentifier("ServerList")

        serverListHorizontalLine.fillColor = viewModel.color(.border)
    }
        
    private func setupWarningSection() {
        warningLabel.isHidden = true
        
        warningLabelHorizontalLine.fillColor = .color(.border, .danger)
        warningLabelHorizontalLine.isHidden = true
        
        warningLabel.setAccessibilityIdentifier("ErrorMessage")
    }
    
    private func setupFooterView() {
        cancelButton.title = LocalizedString.cancel
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonAction)
        
        saveButton.title = LocalizedString.save
        saveButton.target = self
        saveButton.action = #selector(saveButtonAction)
        
        cancelButton.setAccessibilityIdentifier("CancelButton")
        saveButton.setAccessibilityIdentifier("SaveButton")
        
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = .cgColor(.background, .weak)
    }
    
    internal func populateLists(selectedType: Int = 0, selectedCountry: Int = 0, selectedServer: Int = 0, selectedProtocol: Int = 0) {
        refreshTypeList(withSelectionAt: selectedType)
        refreshCountryList(for: selectedType, withSelectionAt: selectedCountry)
        refreshServerList(for: typeList.indexOfSelectedItem, and: selectedCountry, withSelectionAt: selectedServer)
        refreshProtocolList(withSelectionAt: selectedProtocol)
    }
    
    private func refreshTypeList(withSelectionAt selectedIndex: Int) {
        typeList.removeAllItems()
        
        let count = viewModel.typeCount
        for index in 0..<count {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.type(for: index)
            typeList.menu?.addItem(menuItem)
        }
        
        typeList.select(typeList.menu?.item(at: selectedIndex))
    }

    private func refreshPendingEnablement() {
        if viewModel.shouldShowSysexProgress(for: protocolList.indexOfSelectedItem) {
            protocolEnablementProgress.startAnimation(nil)
        } else {
            protocolEnablementProgress.stopAnimation(nil)
        }
    }

    private func refreshProtocolList(withSelectionAt selectedIndex: Int) {
        protocolList.removeAllItems()
        
        for vpnProtocol in viewModel.availableVpnProtocols {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.vpnProtocolString(for: vpnProtocol)
            protocolList.menu?.addItem(menuItem)
        }

        protocolList.selectItem(at: selectedIndex)
        refreshPendingEnablement()
    }

    private func refreshCountryList(for typeIndex: Int, withSelectionAt selectedIndex: Int) {
        countryList.removeAllItems()
        
        let placeholderItem = NSMenuItem()
        placeholderItem.attributedTitle = viewModel.style(LocalizedString.selectCountry, font: .themeFont(.heading4), alignment: .left)
        countryList.menu?.addItem(placeholderItem)
        
        let count = viewModel.countryCount(for: typeIndex)
        for index in 0..<count {
            let menuItem = NSMenuItem()
            menuItem.attributedTitle = viewModel.country(for: typeIndex, index: index)
            countryList.menu?.addItem(menuItem)
        }
        
        countryList.select(countryList.menu?.item(at: selectedIndex))
    }
    
    private func refreshServerList(for typeIndex: Int, and countryIndex: Int, withSelectionAt selectedIndex: Int) {
        serverList.removeAllItems()
        
        let placeholderItem = NSMenuItem()
        placeholderItem.attributedTitle = viewModel.style(LocalizedString.selectServer, font: .themeFont(.heading4), alignment: .left)
        serverList.menu?.addItem(placeholderItem)
        
        if countryIndex > 0 {
            let adjustedCountryIndex = countryIndex - 1
            let count = viewModel.serverCount(for: typeIndex, and: adjustedCountryIndex)
            for index in 0..<count {
                let menuItem = NSMenuItem()
                menuItem.attributedTitle = viewModel.server(for: typeIndex, and: adjustedCountryIndex, index: index)
                serverList.menu?.addItem(menuItem)
            }
        }
        
        serverList.select(serverList.menu?.item(at: selectedIndex))
    }
    
    @objc private func typeSelected() {
        refreshTypeList(withSelectionAt: typeList.indexOfSelectedItem)
        refreshCountryList(for: typeList.indexOfSelectedItem, withSelectionAt: 0)
        refreshServerList(for: typeList.indexOfSelectedItem, and: countryList.indexOfSelectedItem, withSelectionAt: 0)
    }

    @objc private func protocolSelected() {
        let originalIndex = protocolList.indexOfSelectedItem
        viewModel.refreshSysexPending(for: originalIndex)
        refreshProtocolList(withSelectionAt: originalIndex)

        viewModel.checkSysexInstallation(vpnProtocolIndex: protocolList.indexOfSelectedItem) { [weak self] result in
            switch result {
            case let .success(result):
                guard case .installed = result else {
                    break
                }
                
                if self?.protocolList.indexOfSelectedItem != originalIndex {
                    self?.refreshProtocolList(withSelectionAt: originalIndex)
                } else {
                    self?.refreshPendingEnablement()
                }
            case .failure:
                guard let ikeIndex = self?.viewModel.vpnProtocolIndex(for: .ike) else {
                    return
                }
                self?.refreshProtocolList(withSelectionAt: ikeIndex)
            }
        }
    }
    
    @objc private func countrySelected() {
        refreshCountryList(for: typeList.indexOfSelectedItem, withSelectionAt: countryList.indexOfSelectedItem)
        refreshServerList(for: typeList.indexOfSelectedItem, and: countryList.indexOfSelectedItem, withSelectionAt: 0)
    }
    
    @objc private func serverSelected() {
        refreshServerList(for: typeList.indexOfSelectedItem, and: countryList.indexOfSelectedItem, withSelectionAt: serverList.indexOfSelectedItem)
    }
    
    @objc private func cancelButtonAction() {
        if isSessionUnderway {
            let viewModel = WarningPopupViewModel(title: LocalizedString.createNewProfile,
                                                  description: LocalizedString.currentSelectionWillBeLost) { [weak self] in
                self?.viewModel.cancelCreation()
            }
            presentAsModalWindow(WarningPopupViewController(viewModel: viewModel))
            return
        }
        viewModel.cancelCreation()
    }
    
    @objc private func saveButtonAction() {
        var errors = ""
        
        if nameTextField.stringValue.isEmpty {
            errors = appendedWithSeparator(string: errors)
            errors += LocalizedString.profileNameIsRequired
        }
        if nameTextField.stringValue.count > 25 {
            errors = appendedWithSeparator(string: errors)
            errors += LocalizedString.profileNameIsTooLong
        }
        
        let selectedType = typeList.indexOfSelectedItem
        let selectedCountryItem = countryList.indexOfSelectedItem
        let selectedServerItem = serverList.indexOfSelectedItem
        
        if selectedCountryItem == 0 {
            errors = appendedWithSeparator(string: errors)
            errors += LocalizedString.countrySelectionIsRequired
        }
        if selectedServerItem == 0 {
            errors = appendedWithSeparator(string: errors)
            errors += LocalizedString.serverSelectionIsRequired
        }
        
        if !errors.isEmpty {
            presentAlert(errors)
            return
        }
        
        let selectedCountry = selectedCountryItem - 1
        let selectedServer = selectedServerItem - 1
        let selectedColor = viewModel.colorPickerViewModel.color(atIndex: viewModel.colorPickerViewModel.selectedColorIndex)
        
        viewModel.createProfile(name: nameTextField.stringValue, color: selectedColor,
                                typeIndex: selectedType, countryIndex: selectedCountry,
                                serverIndex: selectedServer, vpnProtocolIndex: protocolList.indexOfSelectedItem)
    }
    
    private func appendedWithSeparator(string: String) -> String {
        guard !string.isEmpty else { return string }
        
        return string + ", "
    }
    
    private func presentAlert(_ message: String) {
        warningLabel.attributedStringValue = message.styled(.danger, font: .themeFont(.heading4))
        warningLabel.isHidden = false
        warningLabelHorizontalLine.isHidden = false
    }
    
    private func startObserving() {
        viewModel.prefillContent = { [weak self] information in self?.prefillContent(information) }
        viewModel.contentChanged = { [weak self] in self?.contentChanged() }
        viewModel.contentWarning = { [weak self] message in self?.presentAlert(message) }
        viewModel.secureCoreWarning = { [weak self] in self?.secureCoreWarning() }
        NotificationCenter.default.addObserver(self, selector: #selector(clearContent),
                                               name: viewModel.sessionFinished, object: nil)
    }
    
    private func prefillContent(_ profileInformation: PrefillInformation) {
        clearContent()
        prefill(with: profileInformation)
    }
    
    private func prefill(with profileInformation: PrefillInformation) {
        nameTextField.stringValue = profileInformation.name
        viewModel.colorPickerViewModel.select(color: profileInformation.color)
        
        let adjustedCountryIndex = profileInformation.countryIndex + 1
        let adjustedServerIndex = profileInformation.serverIndex + 1
        
        populateLists(selectedType: profileInformation.typeIndex,
                      selectedCountry: adjustedCountryIndex,
                      selectedServer: adjustedServerIndex,
                      selectedProtocol: profileInformation.vpnProtocolIndex)
    }
    
    private func contentChanged() {
        populateLists()
    }
    
    @objc private func clearContent() {
        nameTextField.stringValue = ""
        viewModel.colorPickerViewModel.selectRandom()
        populateLists()
        warningLabel.isHidden = true
        warningLabelHorizontalLine.isHidden = true
    }
    
    private func secureCoreWarning() {
        presentAsModalWindow(viewModel.createSecureCoreWarningViewController())
    }
}

// MARK: - TextField highlight on focus
extension CreateNewProfileViewController: TextFieldFocusDelegate {
    var shouldBecomeFirstResponder: Bool { true }

    func willReceiveFocus(_ textField: NSTextField) {
        nameTextFieldHorizontalLine.fillColor = .color(.border, .interactive)
    }
}

// MARK: - TextField loss of highlight on loss of focus
extension CreateNewProfileViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        nameTextFieldHorizontalLine.fillColor = viewModel.color(.border)
    }
}

extension CreateNewProfileViewController: NSMenuDelegate {
    func confinementRect(for menu: NSMenu, on screen: NSScreen?) -> NSRect {
        let offset: CGFloat = 120
        let width: CGFloat = 500
        let height: CGFloat = 300
        
        if let typeMenu = typeList.menu, typeMenu == menu {
            return NSRect(x: typeList.frame.minX, y: typeList.frame.minY + offset, width: width, height: height)
        } else if let countryMenu = countryList.menu, countryMenu == menu {
            return NSRect(x: countryList.frame.minX, y: countryList.frame.minY + offset, width: width, height: height)
        } else {
            return NSRect(x: serverList.frame.minX, y: serverList.frame.minY + offset, width: width, height: height)
        }
    }
}
