//
//  ProfilesViewController.swift
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

import UIKit
import GSMessages
import LegacyCommon
import ProtonCoreUIFoundations
import Theme
import Strings
import ProtonCoreFeatureFlags
import Domain

protocol ProfilesViewControllerDelegate: AnyObject {
    func showProfileCreatedSuccessMessage()
    func showProfileEditedSuccessMessage()
    func reloadProfiles()
}

class ProfilesViewController: UIViewController {

    @IBOutlet weak var connectionBarContainerView: UIView!
    @IBOutlet weak var tableView: UITableView!
    
    var viewModel: ProfilesViewModel?
    var connectionBarViewController: ConnectionBarViewController?

    override func awakeFromNib() {
        super.awakeFromNib()

        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.redesigniOS) {
            tabBarItem = UITabBarItem(title: Localizable.profiles, image: IconProvider.windowTerminal, tag: 2)
        } else {
            tabBarItem = UITabBarItem(title: Localizable.profiles, image: IconProvider.bookmark, tag: 3)
        }
        tabBarItem.accessibilityIdentifier = "Profiles"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.redesigniOS) {
            connectionBarContainerView.removeFromSuperview()
        } else {
            setupConnectionBar()
        }
        setupTableView()
        addObservers()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
        renderEditButton()
        renderEditing(tableView.isEditing)
    }

    private func setupView() {
        navigationItem.title = Localizable.profiles
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createProfile))
        renderEditButton()
        
        view.backgroundColor = .backgroundColor()
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor
    }
    
    private func renderEditButton() {
        navigationItem.leftBarButtonItem = self.tableView(tableView, numberOfRowsInSection: 2) > 0 ? self.editButtonItem : nil
    }
    
    private func setupConnectionBar() {
        if let connectionBarViewController = connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        // Fixes inset for profiles, which is not sufficient in the storyboard file
        tableView.separatorInsetReference = .fromAutomaticInsets

        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.estimatedRowHeight = viewModel?.cellHeight ?? UIConstants.cellHeight
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .backgroundColor()
        tableView.allowsSelectionDuringEditing = true
        tableView.separatorStyle = .none
        tableView.register(DefaultProfileTableViewCell.nib, forCellReuseIdentifier: DefaultProfileTableViewCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(contentChanged),
                                               name: VpnKeychain.vpnCredentialsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(contentChanged),
                                               name: ProfileStorage.contentChanged, object: nil)
    }
    
    @objc private func contentChanged() {
        reloadProfiles()
    }
    
    @objc private func createProfile() {
        guard viewModel?.canUseProfiles == true else {
            viewModel?.showProfilesUpsellAlert()
            return
        }
        if let vc = viewModel?.makeCreateProfileViewController() as? CreateProfileViewController {
            vc.profilesViewControllerDelegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ProfilesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.sectionCount ?? 0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel?.headerHeight ?? 0 
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = ServersHeaderView.loadViewFromNib() as ServersHeaderView
        
        headerView.setName(name: viewModel?.title(for: section) ?? "")
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.cellCount(for: section) ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: DefaultProfileTableViewCell.identifier) as? DefaultProfileTableViewCell,
                let cellViewModel = viewModel?.defaultCellModel(for: indexPath.row) {
                cell.viewModel = cellViewModel
                return cell
            }
        } else if indexPath.section == 1 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: ProfilesTableViewCell.identifier, for: indexPath) as? ProfilesTableViewCell,
                let cellViewModel = viewModel?.cellModel(for: indexPath.row) {
                cell.viewModel = cellViewModel
                return cell
            }
        }
        return UITableViewCell() // fallback
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 { // custom profiles
            if let vc = viewModel?.makeEditProfileViewController(for: indexPath.row) as? CreateProfileViewController {
                vc.profilesViewControllerDelegate = self
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 1 {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: Localizable.delete) { [weak self] ( _, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }

            tableView.beginUpdates()
            self.viewModel?.deleteProfile(for: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()

            completionHandler(true)
        }
        action.backgroundColor = .color(.background, .danger)
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        guard viewModel?.canUseProfiles == true else {
            viewModel?.showProfilesUpsellAlert()
            return
        }
        super.setEditing(editing, animated: animated)
        renderEditing(editing)
    }
    
    private func renderEditing(_ editing: Bool) {
        if editing && !tableView.isEditing {
            tableView.setEditing(true, animated: true)
            self.editButtonItem.title = Localizable.done
        } else {
            tableView.setEditing(false, animated: true)
            self.editButtonItem.title = Localizable.edit
            renderEditButton()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 1 {
            return 0.1
        }
        return 0
    }
}

extension ProfilesViewController: ProfilesViewControllerDelegate {
    
    func showProfileCreatedSuccessMessage() {
        showMessage(Localizable.profileCreatedSuccessfully, type: GSMessageType.success, options: UIConstants.messageOptions)
    }
    
    func showProfileEditedSuccessMessage() {
        showMessage(Localizable.profileEditedSuccessfully, type: GSMessageType.success, options: UIConstants.messageOptions)
    }
    
    func reloadProfiles() {
        viewModel?.reloadData()
        tableView.reloadData()
        renderEditButton()
    }
}
