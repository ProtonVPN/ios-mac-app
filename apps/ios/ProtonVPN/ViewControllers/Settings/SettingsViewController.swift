//
//  StatusViewController.swift
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
import vpncore

class SettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var genericDataSource: GenericTableViewDataSource?
    var viewModel: SettingsViewModel? {
        didSet {
            viewModel?.pushHandler = { [pushViewController] viewController in
                pushViewController(viewController)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let selectedImage = UIImage(named: "settings-active")
        let unselectedImage = UIImage(named: "settings-inactive")
        tabBarItem = UITabBarItem(title: LocalizedString.settings, image: unselectedImage, tag: 4)
        tabBarItem.selectedImage = selectedImage
        tabBarItem.accessibilityIdentifier = "Settings"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupTableView()
        tableView.reloadData()
    }
    
    private func setupView() {
        navigationItem.title = LocalizedString.settings
        view.backgroundColor = .protonGrey()
        view.layer.backgroundColor = UIColor.protonGrey().cgColor
    }
    
    private func setupTableView() {
        guard let viewModel = viewModel else { return }
        
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
        
        tableView.separatorColor = .protonBlack()
        tableView.backgroundColor = .protonDarkGrey()
        tableView.cellLayoutMarginsFollowReadableWidth = true
        
        tableView.tableFooterView = viewModel.viewForFooter()
        tableView.contentInset.bottom = UIConstants.cellHeight
    }
    
    private func pushViewController(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
}
