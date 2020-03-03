//
//  CreateProfileViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import GSMessages
import UIKit
import vpncore

class CreateProfileViewController: UITableViewController {
    
    @IBOutlet weak var colorTableViewCell: UITableViewCell!
    @IBOutlet weak var colorPickerCollectionView: UICollectionView!
    
    @IBOutlet weak var profileNameTableViewCell: UITableViewCell!
    @IBOutlet weak var profileNameLabel: UILabel!
    @IBOutlet weak var profileNameTextField: UITextField!
    
    var viewModel: CreateOrEditProfileViewModel?
    
    weak var profilesViewControllerDelegate: ProfilesViewControllerDelegate?
    var colorPickerViewModel: ColorPickerViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupColorPickerCollectionView()
        setupProfileNameRow()
        viewModel?.saveButtonUpdated = { [weak self] in
            self?.renderSaveButton()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Preselects first color
        var select = 0
        if let selected = colorPickerViewModel?.selectedColorIndex {
            select = selected
            
        }
        colorPickerCollectionView.selectItem(at: IndexPath(row: select, section: 0), animated: false, scrollPosition: .top)
    }
    
    // MARK: Table Delegate + Datasource methods
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel?.sectionHeaderSize ?? 0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = ServersHeaderView.loadViewFromNib() as ServersHeaderView
        headerView.setName(name: viewModel?.selectProfileColorLabel ?? "")
        
        return headerView
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows ?? 0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 0:
            return colorPickerViewModel?.height ?? 0
        default:
            return viewModel?.cellHeight ?? 0
        }
    }
    
    // swiftlint:disable cyclomatic_complexity
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            return colorTableViewCell
        case 1:
            return profileNameTableViewCell
        case 2:
            let cell = SwitchTableViewCell.loadViewFromNib() as SwitchTableViewCell
            if let viewModel = viewModel {
                cell.switchControl.isOn = viewModel.isSecureCore
            }
            cell.label.text = LocalizedString.useSecureCore
            cell.switchControl.addTarget(self, action: #selector(secureCoreToggled), for: .valueChanged)
            return cell
        case 3:
            let cell = DrillInTableViewCell.loadViewFromNib() as DrillInTableViewCell
            cell.keyLabel.text = LocalizedString.country
            if let selectedCountry = viewModel?.selectedCountryGroup {
                cell.valueLabel.attributedText = viewModel?.countryDescriptor(for: selectedCountry.0)
            } else {
                cell.valueLabel.text = LocalizedString.selectCountry
            }
            return cell
        case 4:
            let cell = DrillInTableViewCell.loadViewFromNib() as DrillInTableViewCell
            cell.keyLabel.text = LocalizedString.server
            if let selectedServer = viewModel?.selectedServerOffering {
                cell.valueLabel.attributedText = viewModel?.serverName(forServerOffering: selectedServer)
            } else {
                cell.valueLabel.text = LocalizedString.selectServer
            }
            return cell
        case 5:
            let cell = SwitchTableViewCell.loadViewFromNib() as SwitchTableViewCell
            cell.label.text = LocalizedString.makeDefaultProfile
            if let viewModel = viewModel {
                cell.switchControl.isOn = viewModel.isDefaultProfile
            }
            cell.switchControl.addTarget(self, action: #selector(makeDefaultToggled), for: .valueChanged)
            return cell
        default:
            return UITableViewCell()
        }
    }
    // swiftlint:enable cyclomatic_complexity

    // swiftlint:disable cyclomatic_complexity
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            return
        case 1:
            profileNameTextField.becomeFirstResponder()
        case 2:
            if let cell = tableView.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.toggleSelection()
            }
            return
        case 3:
            if let viewModel = viewModel, let countrySelectionViewController = viewModel.makeCountrySelectionViewController() {
                countrySelectionViewController.dataSet = viewModel.countrySelectionDataSet
                countrySelectionViewController.dataSelected = { [self] selectedObject in
                    guard let row = selectedObject as? CountryGroup else { return }
                    self.selected(countryGroup: row)
                }
                self.navigationController?.pushViewController(countrySelectionViewController, animated: true)
            }
        case 4:
            guard let viewModel = viewModel, let dataSet = viewModel.serverSelectionDataSet else {
                self.showMessage(LocalizedString.countrySelectionIsRequired, type: GSMessageType.warning, options: UIConstants.messageOptions)
                return
            }
            if let serverSelectionViewController = viewModel.makeServerSelectionViewController() {
                serverSelectionViewController.dataSet = dataSet
                serverSelectionViewController.dataSelected = { [self] selectedObject in
                    guard let row = selectedObject as? ServerOffering else { return }
                    self.selected(server: row)
                }
                
                self.navigationController?.pushViewController(serverSelectionViewController, animated: true)
            }
        case 5:
            if let cell = tableView.cellForRow(at: indexPath) as? SwitchTableViewCell {
                cell.toggleSelection()
            }
            return
        default:
            return
        }
    }
    // swiftlint:enable cyclomatic_complexity

    @objc private func secureCoreToggled(_ sender: UISwitch) {
        if let viewModel = viewModel {
            viewModel.toggleState { [weak self] succeeded in
                if succeeded {
                    self?.tableView.reloadRows(at: [IndexPath(row: 3, section: 0), IndexPath(row: 4, section: 0)], with: .none)
                } else {
                    sender.setOn(viewModel.isSecureCore, animated: true)
                }
            }
        }
    }
    
    @objc private func makeDefaultToggled() {
        if let viewModel = viewModel {
            viewModel.toggleDefault()
        }
    }
    
    @objc private func handleTap(_ sender: UIGestureRecognizer) {
        profileNameTextField.resignFirstResponder()
    }
    
    @objc func saveTapped() {
        guard let selectedIndex = colorPickerViewModel?.selectedColorIndex,
              let color = colorPickerViewModel?.colorAt(index: selectedIndex),
              let viewModel = viewModel else {
            self.showMessage(LocalizedString.checkIfFieldsPresent, type: GSMessageType.warning, options: UIConstants.messageOptions)
            return
        }
        
        guard let name = profileNameTextField.text, !name.isEmpty else {
            self.showMessage(LocalizedString.profileNameIsRequired, type: GSMessageType.warning, options: UIConstants.messageOptions)
            return
        }
        
        guard viewModel.selectedCountryGroup != nil else {
            self.showMessage(LocalizedString.countrySelectionIsRequired, type: GSMessageType.warning, options: UIConstants.messageOptions)
            return
        }
        
        guard let serverOffering = viewModel.selectedServerOffering else {
            self.showMessage(LocalizedString.serverSelectionIsRequired, type: GSMessageType.warning, options: UIConstants.messageOptions)
            return
        }
        
        let usesSecureCore = viewModel.isSecureCore
        
        let result = viewModel.saveProfile(name: name, color: color, usesSecureCore: usesSecureCore, serverOffering: serverOffering)
        
        switch result {
        case .nameInUse:
            self.showMessage(LocalizedString.profileNameUnique, type: GSMessageType.warning, options: UIConstants.messageOptions)
        default:
            if viewModel.editingExistingProfile {
                profilesViewControllerDelegate?.showProfileEditedSuccessMessage()
            } else {
                profilesViewControllerDelegate?.showProfileCreatedSuccessMessage()
            }
            
            self.navigationController?.popViewController(animated: true)
            profilesViewControllerDelegate?.reloadProfiles()
        }
    }
    
    // MARK: - Private functions
    private func setupView() {
        self.title = LocalizedString.createNewProfile
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: LocalizedString.save, style: .plain, target: self, action: #selector(saveTapped))
        tableView.backgroundColor = viewModel?.backgroundColor
        tableView.separatorColor = .protonBlack()
        tableView.tableFooterView = viewModel?.footerView
        tableView.cellLayoutMarginsFollowReadableWidth = true
        renderSaveButton()
        
        // for dismissing keyboard after name is entered
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }
    
    private func setupColorPickerCollectionView() {
        colorTableViewCell.backgroundColor = .protonGrey()
        colorPickerCollectionView.backgroundColor = .protonGrey()
        colorPickerViewModel = ColorPickerViewModel()
        colorPickerViewModel?.colorChanged = { [weak self] colorPicker in
            self?.viewModel?.saveButtonEnabled = true
        }
        colorPickerCollectionView.delegate = colorPickerViewModel
        colorPickerCollectionView.dataSource = colorPickerViewModel
        colorPickerCollectionView.register(ColorPickerItem.nib,
                                           forCellWithReuseIdentifier: ColorPickerItem.identifier)
        
        if let colorPickerViewModel = colorPickerViewModel, let color = viewModel?.color {
            colorPickerViewModel.select(color: color)
        }
    }
    
    private func setupProfileNameRow() {
        profileNameLabel.text = LocalizedString.name
        profileNameTableViewCell.contentView.backgroundColor = .protonGrey()
        profileNameTableViewCell.backgroundColor = .protonGrey()
        profileNameTableViewCell.selectionStyle = .none
        profileNameLabel.text = LocalizedString.name
        profileNameTextField.attributedPlaceholder = NSAttributedString(string: LocalizedString.enterProfileName, attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        profileNameTextField.delegate = viewModel
        
        if let viewModel = viewModel {
            profileNameTextField.text = viewModel.name
        }
        
        profileNameTextField.addTarget(self, action: #selector(nameTextFieldDidChange), for: .editingChanged)
    }
    
    private func selected(countryGroup: CountryGroup) {
        viewModel?.selectedCountryGroup = countryGroup
        tableView.reloadRows(at: [IndexPath(row: 3, section: 0), IndexPath(row: 4, section: 0)], with: .automatic)
    }
    
    private func selected(server: ServerOffering) {
        viewModel?.selectedServerOffering = server
        tableView.reloadRows(at: [IndexPath(row: 3, section: 0), IndexPath(row: 4, section: 0)], with: .automatic)
    }
    
    @objc private func nameTextFieldDidChange() {
        viewModel?.saveButtonEnabled = true
    }
    
    private func renderSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = viewModel?.saveButtonEnabled ?? false
    }
}
