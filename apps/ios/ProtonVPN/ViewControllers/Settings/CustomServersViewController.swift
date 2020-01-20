//
//  CustomServersViewController.swift
//  ProtonVPN - Created on 09.12.19.
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

class CustomServersViewController: UIViewController {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    private let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addServer))
    
    private var viewModel: CustomServersViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: CustomServersViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: "CustomServers", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupTableView()
        tableView.reloadData()
    }
    
    private func setupView() {
        navigationItem.title = "Custom Servers"
        navigationItem.rightBarButtonItem = addButton
        addButton.isEnabled = false
        
        searchBar.placeholder = "Add VPN server"
        searchBar.returnKeyType = .done
        searchBar.textContentType = .URL
        searchBar.keyboardType = .URL
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.delegate = self
        
        view.backgroundColor = .protonGrey()
        view.layer.backgroundColor = UIColor.protonGrey().cgColor
    }
    
    private func setupTableView() {
        tableView.register(StandardTableViewCell.nib, forCellReuseIdentifier: StandardTableViewCell.identifier)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.separatorColor = .protonBlack()
        tableView.backgroundColor = .protonDarkGrey()
        tableView.cellLayoutMarginsFollowReadableWidth = true
    }
    
    @objc private func addServer() {
        guard let address = searchBar.text else {
            return
        }
        
        searchBar.text = nil
        searchBar.resignFirstResponder()
        
        viewModel.addServer(address: address)
        
        tableView.reloadData()
    }
}

extension CustomServersViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        addButton.isEnabled = !searchText.isEmpty
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        addServer()
    }
}

extension CustomServersViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.tableViewData[0].cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.tableViewData[indexPath.section].cells[indexPath.row] {
        case .standard(title: let title, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
            cell.accessoryType = .none
            cell.label.text = title
            cell.completionHandler = handler
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            viewModel.removeServer(row: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = viewModel.tableViewData[indexPath.section].cells[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)
        
        switch cellModel {
        case .standard:
            guard let cell = cell as? StandardTableViewCell else { return }
            
            cell.select()
        default:
            return
        }
    }
}
