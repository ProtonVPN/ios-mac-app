//
//  SignUpSmsCountryCodeViewController.swift
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

class SmsCountryCodeViewController: UIViewController {
    
    private let searchController = UISearchController(searchResultsController: nil)
    
    @IBOutlet weak var tableView: UITableView!
    
    var viewModel: SmsCountryCodeViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setUpView()
        setUpSearchBar()
        setUpTableView()
    }

    // MARK: - Private functions
    
    private func setUpView() {
        modalPresentationStyle = .formSheet
        view.backgroundColor = .protonBlack()
        title = LocalizedString.selectPhoneCountryCode
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        navigationController?.navigationBar.barTintColor = .protonBlack()
    }
    
    private func setUpSearchBar() {
        if #available(iOS 11.0, *) {
            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.placeholder = LocalizedString.searchPhoneCountryCodePlaceholder
            searchController.searchBar.barStyle = .black
            navigationItem.searchController = searchController
            
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    private func setUpTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.separatorColor = .protonDarkGrey()
        tableView.backgroundColor = .protonBlack()
        tableView.register(PhoneCountryCodeTableViewCell.nib, forCellReuseIdentifier: PhoneCountryCodeTableViewCell.identifier)
    }
    
    @objc private func doneTapped() {
        if #available(iOS 11.0, *) {
            searchController.dismiss(animated: false, completion: nil)
        }
        navigationController?.dismiss(animated: true, completion: nil)
    }
}

// MARK: UITableView delegates

extension SmsCountryCodeViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows() ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel, let phoneCodeCell = tableView.dequeueReusableCell(withIdentifier: PhoneCountryCodeTableViewCell.identifier) as? PhoneCountryCodeTableViewCell else {
            return UITableViewCell()
        }
        
        phoneCodeCell.viewModel = viewModel.cellModel(for: indexPath.row)
        
        return phoneCodeCell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectRow(indexPath.row)
        doneTapped()
    }
}

// MARK: UISearchResultsUpdating

extension SmsCountryCodeViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        viewModel?.updateSearchResults(searchController.searchBar.text)
        tableView.reloadData()
    }
}
