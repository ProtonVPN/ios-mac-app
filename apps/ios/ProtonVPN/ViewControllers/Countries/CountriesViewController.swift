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

class CountriesViewController: UIViewController {
    
    @IBOutlet weak var connectionBarContainerView: UIView!
    @IBOutlet weak var secureCoreBar: UIView!
    @IBOutlet weak var secureCoreLabel: UILabel!
    @IBOutlet weak var secureCoreSwitch: UISwitch!
    @IBOutlet weak var tableView: UITableView!
    
    public var viewModel: CountriesViewModel?
    public var connectionBarViewController: ConnectionBarViewController?
    public var planService: PlanService!
    
    public var countryControllers: [Weak<CountryViewController>] = []
    
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
        setupAnnouncements()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setupAnnouncements), name: AnnouncementStorageNotifications.contentChanged, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAnnouncements()
    }
    
    @objc func switchValueDidChange(sender: UISwitch!) {
        viewModel?.toggleState { [weak self] succeeded in
            DispatchQueue.main.async {
                guard let `self` = self else { return }
                if succeeded {
                    self.tableView.reloadData()
                } else {
                    self.secureCoreSwitch.setOn(self.viewModel?.activeView == .secureCore, animated: true)
                }
            }
        }
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
        secureCoreSwitch.addTarget(self, action: #selector(self.switchValueDidChange), for: .valueChanged)
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
    
    @objc func setupAnnouncements() {
        guard let viewModel = viewModel, viewModel.showAnnouncements else {
            navigationItem.leftBarButtonItem = nil
            return
        }
        
        if navigationItem.leftBarButtonItem == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "bell"), style: .plain, target: self, action: #selector(announcementsButtonTapped))
        }
        
        if viewModel.hasUnreadAnnouncements {
            navigationItem.leftBarButtonItem?.addBadge(offset: CGPoint(x: -9, y: 10), color: .protonGreen())
        } else {
            navigationItem.leftBarButtonItem?.removeBadge()
        }
    }
    
    @IBAction func announcementsButtonTapped() {
        if let controller = viewModel?.announcementsViewController() {
            self.navigationController?.pushViewController(controller, animated: true)
        }
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
        if let cellModel = viewModel?.cellModel(for: indexPath.row, in: indexPath.section) {
            if let countryCell = tableView.dequeueReusableCell(withIdentifier: CountryViewCell.identifier) as? CountryViewCell {
                countryCell.viewModel = cellModel
                return countryCell
            }
        }
        
        return UITableViewCell()
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
