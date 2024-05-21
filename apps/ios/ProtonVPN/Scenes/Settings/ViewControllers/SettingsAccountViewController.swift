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

import UIKit
import LegacyCommon
import Strings

final class SettingsAccountViewController: UIViewController {
    
    private let tableView: UITableView
    private let genericDataSource: GenericTableViewDataSource
    private let connectionBarContainerView: UIView
    private let connectionBar: ConnectionBarViewController
    
    init(viewModel: SettingsAccountViewModel, connectionBar: ConnectionBarViewController) {
        self.tableView = UITableView()
        self.genericDataSource = GenericTableViewDataSource(for: tableView, with: viewModel.tableViewData)
        self.connectionBarContainerView = UIView()
        self.connectionBar = connectionBar
        super.init(nibName: nil, bundle: nil)
        
        viewModel.viewControllerFetcher = { [weak self] in self }
        viewModel.reloadNeeded = { [weak self] in
            guard let self = self, self.isViewLoaded else {
                return
            }

            self.tableView.reloadData()
        }
    }
    
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
        
        view.addSubview(connectionBarContainerView)
        connectionBarContainerView.centerXInSuperview()
        
        NSLayoutConstraint.activate([
            tableView.widthAnchor.constraint(equalTo: view.widthAnchor),
            tableView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: -UIConstants.connectionBarHeight),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            connectionBarContainerView.widthAnchor.constraint(equalTo: view.widthAnchor),
            connectionBarContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            connectionBarContainerView.heightAnchor.constraint(equalToConstant: UIConstants.connectionBarHeight)
        ])
        
        connectionBar.embed(in: self, with: connectionBarContainerView)
        
        tableView.dataSource = genericDataSource
        tableView.delegate = genericDataSource
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)   
        tableView.reloadData()
    }
    
}
