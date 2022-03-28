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
import Search
import ProtonCore_UIFoundations

final class CountriesViewController: UIViewController {
    
    @IBOutlet private weak var connectionBarContainerView: UIView!
    @IBOutlet private weak var secureCoreSeparator: UIView!
    @IBOutlet private weak var secureCoreSeparatorHeight: NSLayoutConstraint!
    @IBOutlet private weak var secureCoreBar: UIView!
    @IBOutlet private weak var secureCoreLabel: UILabel!
    @IBOutlet private weak var secureCoreSwitch: ConfirmationToggleSwitch!
    @IBOutlet private weak var tableView: UITableView!
    
    var viewModel: CountriesViewModel!
    var connectionBarViewController: ConnectionBarViewController?

    var coordinator: SearchCoordinator?
    
    override func awakeFromNib() {
        super.awakeFromNib()

        tabBarItem = UITabBarItem(title: LocalizedString.countries, image: IconProvider.earth, tag: 0)
        tabBarItem.accessibilityIdentifier = "Countries"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.contentChanged = { [weak self] in
            self?.contentChanged()
            self?.reloadSearch()
        }
        setupView()
        setupConnectionBar()
        setupSecureCoreBar()
        setupTableView()
        setupNavigationBar()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setupAnnouncements), name: AnnouncementStorageNotifications.contentChanged, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAnnouncements()
    }
    
    private func setupView() {
        navigationItem.title = LocalizedString.countries
        view.layer.backgroundColor = UIColor.backgroundColor().cgColor
    }
    
    private func setupConnectionBar() {
        if let connectionBarViewController = connectionBarViewController {
            connectionBarViewController.embed(in: self, with: connectionBarContainerView)
        }
    }
    
    private func setupSecureCoreBar() {
        secureCoreSeparator.backgroundColor = .normalSeparatorColor()
        secureCoreSeparatorHeight.constant = 1 / UIScreen.main.scale
        secureCoreBar.backgroundColor = .backgroundColor()
        secureCoreLabel.textColor = .normalTextColor()
        secureCoreLabel.text = LocalizedString.useSecureCore
        secureCoreSwitch.onTintColor = .brandColor()
        if let viewModel = viewModel {
            secureCoreSwitch.isEnabled = viewModel.enableViewToggle
            secureCoreSwitch.isOn = viewModel.secureCoreOn
        }
        secureCoreSwitch.tapped = { [weak self] in
            let toOn = self?.viewModel?.secureCoreOn == true
            self?.viewModel?.toggleState(toOn: !toOn) { [weak self] succeeded in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    self.secureCoreSwitch.setOn(self.viewModel.secureCoreOn, animated: true)

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
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .backgroundColor()
        tableView.register(CountryCell.nib, forCellReuseIdentifier: CountryCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }
    
    private func setupNavigationBar() {
        let infoButton = UIBarButtonItem(image: IconProvider.infoCircle, style: .plain, target: self, action: #selector(displayServicesInfo))
        let searchButton = UIBarButtonItem(image: IconProvider.magnifier, style: .plain, target: self, action: #selector(showSearch))
        navigationItem.rightBarButtonItems = [searchButton, infoButton]
    }
    
    @objc private func displayServicesInfo() {
        let viewModel = ServersFeaturesInformationViewModelImplementation()
        let vc = ServersFeaturesInformationVC(viewModel)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true, completion: nil)
    }
    
    private func contentChanged() {
        guard let viewModel = viewModel else { return }
        secureCoreSwitch.setOn(viewModel.secureCoreOn, animated: true)
        tableView.reloadData()
    }

    func showCountry(cellModel: CountryItemViewModel) {
        if cellModel.isUsersTierTooLow {
            viewModel.presentAllCountriesUpsell()
            return
        }

        guard let countryViewController = viewModel.countryViewController(viewModel: cellModel) else {
            return
        }

        self.navigationController?.pushViewController(countryViewController, animated: true)
    }
}

extension CountriesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if viewModel.numberOfSections() < 2 {
            return nil
        }
        
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView {
            headerView.setName(name: viewModel.titleFor(section: section) ?? "")
            return headerView
        }
        
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.headerHeight(for: section)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = viewModel.cellModel(for: indexPath.row, in: indexPath.section)
        guard let countryCell = tableView.dequeueReusableCell(withIdentifier: CountryCell.identifier) as? CountryCell else {
            return UITableViewCell()
        }

        countryCell.viewModel = cellModel
        return countryCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = viewModel.cellModel(for: indexPath.row, in: indexPath.section)
        showCountry(cellModel: cellModel)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
}
