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

class CreateNewProfileViewController: NSViewController {
    
    @IBOutlet weak var profileSettingsLabel: PVPNTextField!
    @IBOutlet weak var nameLabel: PVPNTextField!
    @IBOutlet weak var nameTextField: TextFieldWithFocus!
    @IBOutlet weak var nameTextFieldHorizontalLine: NSBox!
    @IBOutlet weak var colorPickerLabel: PVPNTextField!
    @IBOutlet weak var colorPickerViewContainer: NSView!
    
    @IBOutlet weak var connectionSettingsLabel: PVPNTextField!
    @IBOutlet weak var typeLabel: PVPNTextField!
    @IBOutlet weak var typeList: HoverDetectionPopUpButton!
    @IBOutlet weak var typeListHorizontalLine: NSBox!
    @IBOutlet weak var countryLabel: PVPNTextField!
    @IBOutlet weak var countryList: HoverDetectionPopUpButton!
    @IBOutlet weak var countryListHorizontalLine: NSBox!
    @IBOutlet weak var serverLabel: PVPNTextField!
    @IBOutlet weak var serverList: HoverDetectionPopUpButton!
    @IBOutlet weak var serverListHorizontalLine: NSBox!
    @IBOutlet weak var netshieldLabel: PVPNTextField!
    @IBOutlet weak var netshieldList: HoverDetectionPopUpButton!
    @IBOutlet weak var netshieldHorizontalLine: NSBox!
    @IBOutlet weak var warningLabel: PVPNTextField!
    @IBOutlet weak var warningLabelHorizontalLine: NSBox!
    @IBOutlet weak var footerView: NSView!
    @IBOutlet weak var saveButton: PrimaryActionButton!
    @IBOutlet weak var cancelButton: WhiteCancelationButton!
    
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
        setupNetshieldSection()
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
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }
    
    private func setupHeaderView() {
        profileSettingsLabel.attributedStringValue = LocalizedString.profileSettings.uppercased().attributed(withColor: .protonGreyOutOfFocus(),
                                                                                                         fontSize: 12, bold: true, alignment: .left)
        connectionSettingsLabel.attributedStringValue = LocalizedString.connectionSettings.uppercased().attributed(withColor: .protonGreyOutOfFocus(),
                                                                                                               fontSize: 12, bold: true, alignment: .left)
    }
    
    private func setupNameSection() {
        nameLabel.attributedStringValue = (LocalizedString.name + ":").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        nameTextField.font = NSFont.systemFont(ofSize: 16)
        nameTextField.textColor = NSColor.protonWhite()
        nameTextField.placeholderAttributedString = LocalizedString.name.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .left)
        nameTextField.drawsBackground = true
        nameTextField.backgroundColor = NSColor.protonGrey()
        nameTextField.focusRingType = .none
        nameTextField.delegate = self
        nameTextField.focusDelegate = self
        
        nameTextFieldHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupColorSection() {
        colorPickerLabel.attributedStringValue = (LocalizedString.color + ":").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        colorPickerViewController = ColorPickerViewController(viewModel: viewModel.colorPickerViewModel)
        colorPickerViewContainer.pin(viewController: colorPickerViewController)
    }
    
    private func setupTypeSection() {
        typeLabel.attributedStringValue = (LocalizedString.serverType + ":").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        typeList.isBordered = false
        typeList.menu?.delegate = self
        typeList.target = self
        typeList.action = #selector(typeSelected)
        
        typeListHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupCountrySection() {
        countryLabel.attributedStringValue = (LocalizedString.country + ":").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        countryList.isBordered = false
        countryList.menu?.delegate = self
        countryList.target = self
        countryList.action = #selector(countrySelected)
        
        countryListHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupServerSection() {
        serverLabel.attributedStringValue = (LocalizedString.server + ":").attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        
        serverList.isBordered = false
        serverList.menu?.delegate = self
        serverList.target = self
        serverList.action = #selector(serverSelected)
        
        serverListHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupNetshieldSection() {
        netshieldLabel.attributedStringValue = LocalizedString.netshieldTitle.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        netshieldList.isBordered = false
        netshieldList.menu?.delegate = self
        netshieldList.target = self
        netshieldList.action = #selector(selectedNetshieldType)
        netshieldHorizontalLine.fillColor = .protonLightGrey()
    }
    
    private func setupWarningSection() {
        warningLabel.isHidden = true
        
        warningLabelHorizontalLine.fillColor = .protonRed()
        warningLabelHorizontalLine.isHidden = true
    }
    
    private func setupFooterView() {
        cancelButton.title = LocalizedString.cancel
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonAction)
        
        saveButton.title = LocalizedString.save
        saveButton.target = self
        saveButton.action = #selector(saveButtonAction)
        
        footerView.wantsLayer = true
        footerView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
    }
    
    internal func populateLists(selectedType: Int = 0, selectedCountry: Int = 0, selectedServer: Int = 0, selectedNetshield: Int = 1) {
        refreshTypeList(withSelectionAt: selectedType)
        refreshCountryList(for: selectedType, withSelectionAt: selectedCountry)
        refreshServerList(for: typeList.indexOfSelectedItem, and: selectedCountry, withSelectionAt: selectedServer)
        refreshNetshieldList(selectedNetshield)
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

    private func refreshCountryList(for typeIndex: Int, withSelectionAt selectedIndex: Int) {
        countryList.removeAllItems()
        
        let placeholderItem = NSMenuItem()
        placeholderItem.attributedTitle = LocalizedString.selectCountry.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .left)
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
        placeholderItem.attributedTitle = LocalizedString.selectServer.attributed(withColor: .protonGreyOutOfFocus(), fontSize: 16, alignment: .left)
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
    
    private func refreshNetshieldList( _ index: Int) {
        netshieldList.isHidden = !viewModel.isNetshieldEnabled
        netshieldLabel.isHidden = !viewModel.isNetshieldEnabled
        netshieldHorizontalLine.isHidden = !viewModel.isNetshieldEnabled
        
        netshieldList.removeAllItems()
        [LocalizedString.disabled, LocalizedString.netshieldLevel1, LocalizedString.netshieldLevel2].forEach { option in
            let item = NSMenuItem()
            item.attributedTitle = option.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
            netshieldList.menu?.addItem(item)
        }
        netshieldList.select(netshieldList.itemArray[index])
    }
    
    @objc private func typeSelected() {
        refreshTypeList(withSelectionAt: typeList.indexOfSelectedItem)
        refreshCountryList(for: typeList.indexOfSelectedItem, withSelectionAt: 0)
        refreshServerList(for: typeList.indexOfSelectedItem, and: countryList.indexOfSelectedItem, withSelectionAt: 0)
    }
    
    @objc private func countrySelected() {
        refreshCountryList(for: typeList.indexOfSelectedItem, withSelectionAt: countryList.indexOfSelectedItem)
        refreshServerList(for: typeList.indexOfSelectedItem, and: countryList.indexOfSelectedItem, withSelectionAt: 0)
    }
    
    @objc private func serverSelected() {
        refreshServerList(for: typeList.indexOfSelectedItem, and: countryList.indexOfSelectedItem, withSelectionAt: serverList.indexOfSelectedItem)
    }
    
    @objc private func selectedNetshieldType() {
        if netshieldList.indexOfSelectedItem != NetShieldType.level2.rawValue {
            refreshNetshieldList(netshieldList.indexOfSelectedItem)
            return
        }
        
        let condition = viewModel.checkNetshieldOption(netshieldList.indexOfSelectedItem)
        refreshNetshieldList( condition ? NetShieldType.level2.rawValue : NetShieldType.defaultValue.rawValue)
    }
    
    @objc private func cancelButtonAction() {
        if isSessionUnderway {
            let viewModel = WarningPopupViewModel(image: #imageLiteral(resourceName: "temp"), title: LocalizedString.createNewProfileHeader,
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
        if nameTextField.stringValue.count > 18 {
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
        let selectedNetshield = NetShieldType(rawValue: netshieldList.indexOfSelectedItem) ?? NetShieldType.defaultValue
        
        viewModel.createProfile(name: nameTextField.stringValue, color: selectedColor,
                                typeIndex: selectedType, countryIndex: selectedCountry,
                                serverIndex: selectedServer, netshieldType: selectedNetshield)
    }
    
    private func appendedWithSeparator(string: String) -> String {
        guard !string.isEmpty else { return string }
        
        return string + ", "
    }
    
    private func presentAlert(_ message: String) {
        warningLabel.attributedStringValue = message.attributed(withColor: .protonRed(), fontSize: 16)
        warningLabel.isHidden = false
        warningLabelHorizontalLine.isHidden = false
    }
    
    private func startObserving() {
        viewModel.prefillContent = { [unowned self] information in self.prefillContent(information) }
        viewModel.contentChanged = { [unowned self] in self.contentChanged() }
        viewModel.contentWarning = { [unowned self] message in self.presentAlert(message) }
        viewModel.secureCoreWarning = { [unowned self] in self.secureCoreWarning() }
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
                      selectedNetshield: profileInformation.netshieldType.rawValue
        )
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
        presentAsModalWindow(SecureCoreWarningViewController())
    }
}

// MARK: - TextField highlight on focus
extension CreateNewProfileViewController: TextFieldFocusDelegate {
    
    func didReceiveFocus(_ textField: NSTextField) {
        nameTextFieldHorizontalLine.fillColor = NSColor.protonGreen()
    }
}

// MARK: - TextField loss of highlight on loss of focus
extension CreateNewProfileViewController: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        nameTextFieldHorizontalLine.fillColor = NSColor.protonLightGrey()
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
