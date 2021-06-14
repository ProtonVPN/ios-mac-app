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

class CountryViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var connectionBarContainerView: UIView!
    
    var viewModel: CountryItemViewModel?
    public var connectionBarViewController: ConnectionBarViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConnectionBar()
        setupTableView()
    }
    
    private func setupView() {
        view.layer.backgroundColor = UIColor.protonDarkGrey().cgColor
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
        tableView.rowHeight = viewModel?.cellHeight ?? 61
        tableView.separatorColor = UIColor.protonBlack()
        tableView.backgroundColor = .protonDarkGrey()
        tableView.register(ServerViewCell.nib, forCellReuseIdentifier: ServerViewCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }
    
    private func displayStreamingServices() {
        guard let viewModel = viewModel else { return }
        let services = viewModel.streamingServices
        let countryName = viewModel.countryName
        let streamingFeaturesViewModel = ServersStreamingFeaturesViewModelImplementation(country: countryName, streamServices: services, propertiesManager: viewModel.propertiesManager )
        let vc = ServersStreamingFeaturesVC(streamingFeaturesViewModel)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }
}

extension CountryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.sectionsCount() ?? 1
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView {
            headerView.setName(name: viewModel?.titleFor(section: section) ?? "")
            headerView.callback = nil
            if let viewModel = self.viewModel, viewModel.streamingAvailable, viewModel.isSeverPlus(for: section) {
                headerView.callback = { [weak self] in
                    self?.displayStreamingServices()
                }
            }
            return headerView
        }
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UIConstants.countriesHeaderHeight
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.serversCount(for: section) ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cellModel = viewModel?.cellModel(for: indexPath.row, section: indexPath.section) {
            if let secureCoreCellModel = cellModel as? SecureCoreServerItemViewModel {
                if let serverCell = tableView.dequeueReusableCell(withIdentifier: ServerViewCell.identifier) as? ServerViewCell {
                    serverCell.viewModel = secureCoreCellModel
                    return serverCell
                }
            } else {
                if let serverCell = tableView.dequeueReusableCell(withIdentifier: ServerViewCell.identifier) as? ServerViewCell {
                    serverCell.viewModel = cellModel
                    return serverCell
                }
            }
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let sectionCount = numberOfSections(in: tableView)
        if section == sectionCount - 1 {
            return 0.1
        }
        
        return 0
    }
}
