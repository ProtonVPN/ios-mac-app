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

import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Search
import UIKit

final class CountryViewController: UIViewController {
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.allowsSelectionDuringEditing = true
        return tableView
    }()

    var viewModel: CountryItemViewModel

    init(viewModel: CountryItemViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupView()
        setupTableView()
    }

    private func setupViews() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func setupView() {
        view.layer.backgroundColor = UIColor.secondaryBackgroundColor().cgColor
        title = viewModel.countryName
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self

        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.separatorColor = UIColor.normalSeparatorColor()
        tableView.backgroundColor = .backgroundColor()
        tableView.register(ServerCell.nib, forCellReuseIdentifier: ServerCell.identifier)
        tableView.register(ServersHeaderView.self, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }

    private func displayStreamingServices() {
        let services = viewModel.streamingServices
        let countryName = viewModel.countryName
        let streamingFeaturesViewModel = ServersStreamingFeaturesViewModelImplementation(country: countryName, streamServices: services)
        let vc = ServersStreamingFeaturesVC(streamingFeaturesViewModel)
        present(vc, animated: true, completion: nil)
    }
}

extension CountryViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel.sectionsCount()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard viewModel.showServerHeaders, let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView else {
            return UIView()
        }

        headerView.setName(name: viewModel.titleFor(section: section))
        headerView.callback = nil

        if viewModel.streamingAvailable, viewModel.isServerPlusOrAbove(for: section) {
            headerView.callback = { [weak self] in
                self?.displayStreamingServices()
            }
        }
        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        UIConstants.countriesHeaderHeight
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.serversCount(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = viewModel.cellModel(for: indexPath.row, section: indexPath.section)
        guard let serverCell = tableView.dequeueReusableCell(withIdentifier: ServerCell.identifier) as? ServerCell else {
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
