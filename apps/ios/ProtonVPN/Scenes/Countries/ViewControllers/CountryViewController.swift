//
//  CountryViewController.swift
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
import Search
import ProtonCoreUIFoundations

final class CountryViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var connectionBarContainerView: UIView!
    
    var viewModel: CountryItemViewModel?
    var connectionBarViewController: ConnectionBarViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConnectionBar()
        setupTableView()
    }
    
    private func setupView() {
        view.layer.backgroundColor = UIColor.secondaryBackgroundColor().cgColor
        self.title = viewModel?.countryName
    }
    
    private func setupConnectionBar() {
        if let connectionBarViewController = connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.separatorColor = UIColor.normalSeparatorColor()
        tableView.backgroundColor = .backgroundColor()
        tableView.register(ServerCell.nib, forCellReuseIdentifier: ServerCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }

    private func displayStreamingServices() {
        guard let viewModel = viewModel else { return }
        let services = viewModel.streamingServices
        let countryName = viewModel.countryName
        let streamingFeaturesViewModel = ServersStreamingFeaturesViewModelImplementation(country: countryName, streamServices: services, propertiesManager: viewModel.propertiesManager )
        let vc = ServersStreamingFeaturesVC(streamingFeaturesViewModel)
        present(vc, animated: true, completion: nil)
    }
}

extension CountryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.sectionsCount() ?? 1
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard viewModel?.showServerHeaders ?? false, let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView else {
            return UIView()
        }

        headerView.setName(name: viewModel?.titleFor(section: section) ?? "")
        headerView.callback = nil
        guard let viewModel else {
            return headerView
        }
        if viewModel.streamingAvailable, viewModel.isServerPlusOrAbove(for: section) {
            headerView.callback = { [weak self] in
                self?.displayStreamingServices()
            }
        }
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UIConstants.countriesHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.serversCount(for: section) ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellModel = viewModel?.cellModel(for: indexPath.row, section: indexPath.section), let serverCell = tableView.dequeueReusableCell(withIdentifier: ServerCell.identifier) as? ServerCell else {
            return UITableViewCell()
        }

        serverCell.viewModel = cellModel
        serverCell.delegate = self
        return serverCell
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let sectionCount = numberOfSections(in: tableView)
        if section == sectionCount - 1 {
            return 0.1
        }
        
        return 0
    }
}

extension CountryViewController: ServerCellDelegate {
    func userDidRequestStreamingInfo() {
        displayStreamingServices()
    }
}
