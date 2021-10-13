//
//  SelectionViewController.swift
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

struct SelectionSection {
    let title: String?
    let cells: [SelectionRow]
}

struct SelectionRow {
    let title: NSAttributedString
    let object: Any
}

struct SelectionDataSet {
    var dataTitle: String
    var data: [SelectionSection]
    var selectedIndex: IndexPath?
    
    public func section(at index: Int) -> SelectionSection {
        return data[index]
    }
    
    public func item(at indexPath: IndexPath) -> SelectionRow {
        return section(at: indexPath.section).cells[indexPath.row]
    }
}

class SelectionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var dataSet: SelectionDataSet!
    var dataSelected: ((Any) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTableView()
    }
    
    func setupView() {
        self.title = dataSet.dataTitle
    }
    
    func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.backgroundColor = .backgroundColor()
        tableView.rowHeight = UIConstants.cellHeight
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .normalSeparatorColor()
        tableView.register(SelectionTableViewCell.nib, forCellReuseIdentifier: SelectionTableViewCell.identifier)
        tableView.register(ServersHeaderView.nib, forHeaderFooterViewReuseIdentifier: ServersHeaderView.identifier)
    }
}

extension SelectionViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSet.data.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ServersHeaderView.identifier) as? ServersHeaderView {
            if let title = dataSet.section(at: section).title {
                headerView.setName(name: title)
                return headerView
            }
        }
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if dataSet.section(at: section).title != nil {
            return UIConstants.headerHeight
        }
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSet.data[section].cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: SelectionTableViewCell.identifier, for: indexPath) as? SelectionTableViewCell {
            
            cell.nameLabel.attributedText = dataSet.item(at: indexPath).title
            
            if let index = dataSet.selectedIndex, index == indexPath {
                cell.accessoryType = .checkmark
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            } else {
                cell.accessoryType = .none
            }
            return cell
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
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let oldIndex = tableView.indexPathForSelectedRow {
            tableView.cellForRow(at: oldIndex)?.accessoryType = .none
        }
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        dataSet.selectedIndex = indexPath
        dataSelected?(dataSet.item(at: indexPath).object)
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.navigationController?.popViewController(animated: true)
    }
}
