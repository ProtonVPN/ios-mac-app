//
//  ServersFeaturesInformationVC.swift
//  ProtonVPN - Created on 21.04.21.
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

import LegacyCommon
import ProtonCoreUIFoundations
import Strings
import UIKit

class ServersFeaturesInformationVC: UIViewController {
    @IBOutlet var titleLbl: UILabel!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var featuresTableView: UITableView!
    
    let viewModel: ServersFeaturesInformationViewModel
    
    init(_ viewModel: ServersFeaturesInformationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - ViewCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .backgroundColor()
        titleLbl.text = Localizable.informationTitle
        closeButton.setImage(IconProvider.crossBig, for: .normal) 
        featuresTableView.register(FeatureTableViewCell.nib, forCellReuseIdentifier: FeatureTableViewCell.identifier)
        featuresTableView.dataSource = self
        featuresTableView.delegate = self
    }
    
    // MARK: - Actions
    
    @IBAction func didTapDismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension ServersFeaturesInformationVC: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.totalFeatures
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.featuresCount(for: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FeatureTableViewCell.identifier, for: indexPath) as! FeatureTableViewCell
        cell.viewModel = viewModel.getFeatureViewModel(indexPath: indexPath)
        return cell
    }
}

extension ServersFeaturesInformationVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        viewModel.headerHeight
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = ServersHeaderView.loadViewFromNib() as ServersHeaderView
        headerView.setName(name: viewModel.titleFor(section))
        headerView.setColor(color: .backgroundColor())
        return headerView
    }
}
