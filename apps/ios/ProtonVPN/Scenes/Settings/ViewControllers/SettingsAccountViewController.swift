//
//  Created on 03/02/2022.
//
//  Copyright (c) 2022 Proton AG
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

import LegacyCommon
import ProtonCoreFeatureFlags
import Strings
import UIKit

final class SettingsAccountViewController: UIViewController {
    private let viewModel: SettingsAccountViewModel
    private let tableView: UITableView
    private let genericDataSource: GenericTableViewDataSource
    private let connectionBarContainerView: UIView
    private let connectionBar: ConnectionBarViewController

    init(viewModel: SettingsAccountViewModel, connectionBar: ConnectionBarViewController) {
        self.viewModel = viewModel
        tableView = UITableView()
        genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        connectionBarContainerView = UIView()
        self.connectionBar = connectionBar
        super.init(nibName: nil, bundle: nil)

        viewModel.viewControllerFetcher = { [weak self] in self }
        viewModel.pushHandler = { [weak self] viewController in
            self?.navigationController?.pushViewController(viewController, animated: true)
        }
        viewModel.reloadNeeded = { [weak self] in
            guard let self, isViewLoaded else {
                return
            }

            tableView.reloadData()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = Localizable.account

        view.backgroundColor = .backgroundColor()
        tableView.separatorColor = .normalSeparatorColor()
        tableView.backgroundColor = .backgroundColor()
        tableView.cellLayoutMarginsFollowReadableWidth = true

        view.addSubview(tableView)
        tableView.centerXInSuperview()
        if !FeatureFlagsRepository.isRedesigniOSEnabled {
            view.addSubview(connectionBarContainerView)
            connectionBarContainerView.centerXInSuperview()

            NSLayoutConstraint.activate([
                tableView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -UIConstants.connectionBarHeight),

                connectionBarContainerView.widthAnchor.constraint(equalTo: view.widthAnchor),
                connectionBarContainerView.topAnchor.constraint(equalTo: view.topAnchor),
                connectionBarContainerView.heightAnchor.constraint(equalToConstant: UIConstants.connectionBarHeight),
            ])

            connectionBar.embed(in: self, with: connectionBarContainerView)
        } else {
            NSLayoutConstraint.activate([tableView.heightAnchor.constraint(equalTo: view.heightAnchor)])
        }

        NSLayoutConstraint.activate([
            tableView.widthAnchor.constraint(equalTo: view.widthAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)   
        tableView.reloadData()
    }
}
