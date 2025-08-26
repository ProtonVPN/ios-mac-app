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
import Domain
import Ergonomics
import LegacyCommon
import Strings

final class SettingsViewController: UIViewController {
    private var tableView: UITableView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.separatorColor = .normalSeparatorColor()
        $0.separatorInset = .zero
        $0.backgroundColor = .backgroundColor()
        $0.cellLayoutMarginsFollowReadableWidth = true
        $0.contentInset.bottom = UIConstants.cellHeight
    }

    private lazy var connectionBarContainerView: UIView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    var connectionBarViewController: ConnectionBarViewController?
    var genericDataSource: GenericTableViewDataSource?

    private let viewModel: SettingsViewModel

    // MARK: - Init

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        self.viewModel.showModalController = { [weak self] viewController in
            self?.present(viewController, animated: true)
        }
        self.viewModel.pushHandler = { [weak self] viewController, translucent, hidesBackButton in
            self?.pushViewController(viewController, translucentNavBar: translucent, hidesBackButton: hidesBackButton)
        }
        self.viewModel.reloadNeeded = { [weak self] in
            guard let self, isViewLoaded else {
                return
            }

            setupTableView()
            tableView.reloadData()
        }
        // Set up tab bar item
        if FeatureFlagsRepository.isRedesigniOSEnabled {
            tabBarItem = UITabBarItem(title: Localizable.settings, image: IconProvider.cogWheel, tag: 3)
        } else {
            tabBarItem = UITabBarItem(title: Localizable.settings, image: IconProvider.cogWheel, tag: 4)
        }
        tabBarItem.accessibilityIdentifier = "Settings back btn"
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()

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

        view.addSubview(tableView)

        if FeatureFlagsRepository.isRedesigniOSEnabled {
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        } else {
            view.addSubview(connectionBarContainerView)

            NSLayoutConstraint.activate([
                connectionBarContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                connectionBarContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                connectionBarContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                connectionBarContainerView.heightAnchor.constraint(equalToConstant: .themeSpacing48),

                tableView.topAnchor.constraint(equalTo: connectionBarContainerView.bottomAnchor),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])

            setupConnectionBar()
        }
    }

    private func setupTableView() {
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
        tableView.tableFooterView = viewModel.viewForFooter()
    }

    private func pushViewController(_ viewController: UIViewController, translucentNavBar: Bool, hidesBackButton: Bool) {
        navigationController?.navigationBar.isTranslucent = translucentNavBar
        navigationController?.navigationBar.backgroundColor = translucentNavBar ? .clear : nil

        if hidesBackButton {
            navigationItem.backBarButtonItem = .emptyBackBarButtonItem
        }

        navigationController?.pushViewController(viewController, animated: true)
    }

    private func setupConnectionBar() {
        if let connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
}

private extension UIBarButtonItem {
    static let emptyBackBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
}
