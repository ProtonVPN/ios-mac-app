//
//  FirstViewController.swift
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

final class CountriesViewController: UIViewController {
    
    @IBOutlet private weak var connectionBarContainerView: UIView!
    @IBOutlet private weak var secureCoreBar: UIView!
    @IBOutlet private weak var secureCoreLabel: UILabel!
    @IBOutlet private weak var secureCoreSwitch: ConfirmationToggleSwitch!
    @IBOutlet private weak var tableView: UITableView!
    
    var viewModel: CountriesViewModel?
    var connectionBarViewController: ConnectionBarViewController?
    var planService: PlanService!
    
    var countryControllers: [Weak<CountryViewController>] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let selectedImage = UIImage(named: "countries-active")
        let unselectedImage = UIImage(named: "countries-inactive")
        tabBarItem = UITabBarItem(title: LocalizedString.countries, image: unselectedImage, tag: 0)
        tabBarItem.selectedImage = selectedImage
        tabBarItem.accessibilityIdentifier = "Countries"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel?.contentChanged = { [weak self] in self?.contentChanged() }
        viewModel?.connectionChanged = { [secureCoreSwitch, viewModel] in
            DispatchQueue.main.async {
                secureCoreSwitch?.isEnabled = viewModel?.enableViewToggle ?? false
            }
        }
        
        setupView()
        setupConnectionBar()
        setupSecureCoreBar()
        setupTableView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setupAnnouncements), name: AnnouncementStorageNotifications.contentChanged, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAnnouncements()
    }
    
    private func setupView() {
        navigationItem.title = LocalizedString.countries
        view.layer.backgroundColor = UIColor.protonGrey().cgColor
    }
    
    private func setupConnectionBar() {
        if let connectionBarViewController = connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
    
    private func setupSecureCoreBar() {
        secureCoreBar.backgroundColor = .protonDarkGrey()
        secureCoreLabel.textColor = .protonWhite()
        secureCoreLabel.text = LocalizedString.useSecureCore
        secureCoreSwitch.onTintColor = .protonConnectGreen()
        if let viewModel = viewModel {
            secureCoreSwitch.isEnabled = viewModel.enableViewToggle
            secureCoreSwitch.isOn = viewModel.secureCoreOn
        }
        secureCoreSwitch.tapped = { [weak self] in
            self?.viewModel?.toggleState { [weak self] succeeded in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    self.secureCoreSwitch.setOn(self.viewModel?.secureCoreOn == true, animated: true)

                    if succeeded {
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self

        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = viewModel?.cellHeight ?? 61
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.protonBlack()
        tableView.backgroundColor = .protonDarkGrey()
        tableView.register(CountryViewCell.nib, forCellReuseIdentifier: CountryViewCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }
    
    private func contentChanged() {
        guard let viewModel = viewModel else { return }
        
        secureCoreSwitch.setOn(viewModel.secureCoreOn, animated: true)
        tableView.reloadData()
    }
    
}

extension CountriesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.numberOfSections() ?? 1
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView {
            headerView.setName(name: viewModel?.titleFor(section: section) ?? "")
            return headerView
        }
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel?.headerHeight(for: section) ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows(in: section) ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellModel = viewModel?.cellModel(for: indexPath.row, in: indexPath.section), let countryCell = tableView.dequeueReusableCell(withIdentifier: CountryViewCell.identifier) as? CountryViewCell else {
            return UITableViewCell()
        }

        countryCell.viewModel = cellModel
        return countryCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cellModel = viewModel?.cellModel(for: indexPath.row, in: indexPath.section) else {
            return
        }
        
        if indexPath.section > 0 { // Premium countries
            planService.presentPlanSelection()
            return
        }
        
        if let countryViewController = viewModel?.countryViewController(viewModel: cellModel) {
            countryControllers.append(Weak(value: countryViewController))
            self.navigationController?.pushViewController(countryViewController, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
}
