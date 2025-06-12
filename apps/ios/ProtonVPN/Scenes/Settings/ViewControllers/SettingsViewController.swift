//
//  SettingsViewController.swift
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

import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations

import Announcement
import LegacyCommon

import Domain
import Strings

final class SettingsViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var connectionBarContainerView: UIView!

    var connectionBarViewController: ConnectionBarViewController?
    var genericDataSource: GenericTableViewDataSource?
    var viewModel: SettingsViewModel? {
        didSet {
            viewModel?.pushHandler = { [pushViewController] viewController in
                pushViewController(viewController)
            }
            viewModel?.reloadNeeded = { [weak self] in
                guard let self, isViewLoaded else {
                    return
                }

                setupTableView()
                tableView.reloadData()
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if FeatureFlagsRepository.isRedesigniOSEnabled {
            tabBarItem = UITabBarItem(title: Localizable.settings, image: IconProvider.cogWheel, tag: 3)
        } else {
            tabBarItem = UITabBarItem(title: Localizable.settings, image: IconProvider.cogWheel, tag: 4)
        }
        tabBarItem.accessibilityIdentifier = "Settings back btn"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        if FeatureFlagsRepository.isRedesigniOSEnabled {
            connectionBarContainerView.removeFromSuperview()
        } else {
            setupConnectionBar()
        }

        AppEvent.announcementStorageContent.subscribe(self, selector: #selector(setupAnnouncements))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupTableView()
        tableView.reloadData()

        /// This is required by QR Login. One of the views in the QR Login flow hides the navigation bar and we need to make sure it is visible when we pop back to the root view controller.
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func setupView() {
        navigationItem.title = Localizable.settings
        view.backgroundColor = .backgroundColor()
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor
    }

    private func setupTableView() {
        guard let viewModel else { return }

        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource

        tableView.separatorColor = .normalSeparatorColor()
        tableView.separatorInset = .zero
        tableView.backgroundColor = .backgroundColor()
        tableView.cellLayoutMarginsFollowReadableWidth = true

        tableView.tableFooterView = viewModel.viewForFooter()
        tableView.contentInset.bottom = UIConstants.cellHeight
    }

    private func pushViewController(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func setupConnectionBar() {
        if let connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
}
