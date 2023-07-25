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
import LegacyCommon

class CreateProfileViewController: UITableViewController {
    
    private var genericDataSource: GenericTableViewDataSource?
    
    var viewModel: CreateOrEditProfileViewModel? {
        didSet {
            viewModel?.saveButtonUpdated = { [weak self] in
                self?.renderSaveButton()
            }
            viewModel?.contentChanged = { [weak self] in
                self?.updateTableView()
                self?.tableView.reloadData()
            }
            viewModel?.messageHandler = { [weak self] text, type, options in
                self?.showMessage(text, type: type, options: options)
            }
            viewModel?.pushHandler = { [weak self] viewController in
                self?.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
    
    weak var profilesViewControllerDelegate: ProfilesViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateTableView()
        tableView.reloadData()
    }
    
    // MARK: - Private functions
    private func setupView() {
        self.title = LocalizedString.createNewProfile
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: LocalizedString.save, style: .plain, target: self, action: #selector(saveTapped))
        renderSaveButton()
        
        // for dismissing keyboard after name is entered
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }
    
    private func setupTableView() {
        updateTableView()
        
        tableView.separatorColor = .normalSeparatorColor()
        tableView.backgroundColor = .backgroundColor()
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }
    
    private func updateTableView() {
        guard let viewModel = viewModel else { return }
        
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }
    
    @objc private func handleTap(_ sender: UIGestureRecognizer) {
        view.endEditing(true)
    }
    
    @objc private func saveTapped() {
        guard let viewModel = viewModel else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        viewModel.saveProfile { success in
            guard success else {
                return
            }

            if viewModel.editingExistingProfile {
                self.profilesViewControllerDelegate?.showProfileEditedSuccessMessage()
            } else {
                self.profilesViewControllerDelegate?.showProfileCreatedSuccessMessage()
            }

            self.navigationController?.popViewController(animated: true)
            self.profilesViewControllerDelegate?.reloadProfiles()
        }
    }

    private func renderSaveButton() {
        navigationItem.rightBarButtonItem?.isEnabled = viewModel?.saveButtonEnabled ?? false
    }
}
