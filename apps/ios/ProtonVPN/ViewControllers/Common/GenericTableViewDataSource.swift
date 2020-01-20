//
//  GenericTableViewDataSource.swift
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

enum TableViewCellModel {
    
    case standard(title: String, handler: (() -> Void) )
    case keyValue(key: String, value: String)
    case toggle(title: String, on: Bool, enabled: Bool, handler: ((Bool) -> Void)? )
    case button(title: String, accessibilityIdentifier: String?, color: UIColor, handler: (() -> Void) )
    case tooltip(text: String)
    case instructionStep(number: Int, text: String)
}

struct TableViewSection {
    
    let title: String
    let cells: [TableViewCellModel]
}

// A generic data source for table views
class GenericTableViewDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    let sections: [TableViewSection]
    
    init(for tableView: UITableView, with sections: [TableViewSection]) {
        self.sections = sections
        
        tableView.register(StandardTableViewCell.nib, forCellReuseIdentifier: StandardTableViewCell.identifier)
        tableView.register(KeyValueTableViewCell.nib, forCellReuseIdentifier: KeyValueTableViewCell.identifier)
        tableView.register(SwitchTableViewCell.nib, forCellReuseIdentifier: SwitchTableViewCell.identifier)
        tableView.register(TooltipTableViewCell.nib, forCellReuseIdentifier: TooltipTableViewCell.identifier)
        tableView.register(ButtonTableViewCell.nib, forCellReuseIdentifier: ButtonTableViewCell.identifier)
        tableView.register(InstructionStepTableViewCell.nib, forCellReuseIdentifier: InstructionStepTableViewCell.identifier)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = sections[indexPath.section].cells[indexPath.row]
        
        switch cellModel {
        case .standard(title: let title, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
            cell.label.text = title
            cell.completionHandler = handler
            
            return cell
        case .keyValue(key: let key, value: let value):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: KeyValueTableViewCell.identifier) as? KeyValueTableViewCell else {
                return UITableViewCell()
            }
            cell.viewModel = [key: value]
            
            return cell
        case .toggle(title: let title, on: let on, enabled: let enabled, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.identifier) as? SwitchTableViewCell else {
                return UITableViewCell()
            }
            cell.label.text = title
            cell.switchControl.onTintColor = enabled ? .protonConnectGreen() : .protonGreen()
            cell.switchControl.isOn = on
            cell.switchControl.isEnabled = enabled
            cell.toggled = handler
            
            return cell
        case .button(title: let title, accessibilityIdentifier: let accessibilityIdentifier, color: let color, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ButtonTableViewCell.identifier) as? ButtonTableViewCell else {
                return UITableViewCell()
            }            
            cell.button.setTitle(title, for: .normal)
            cell.button.setTitleColor(color, for: .normal)
            cell.button.accessibilityIdentifier = accessibilityIdentifier
            cell.completionHandler = handler
            
            return cell
        case .tooltip(text: let text):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TooltipTableViewCell.identifier) as? TooltipTableViewCell else {
                return UITableViewCell()
            }
            cell.tooltipLabel.attributedText = TooltipTableViewCell.attributedText(for: text)
            
            return cell
        case .instructionStep(number: let number, text: let text):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: InstructionStepTableViewCell.identifier) as? InstructionStepTableViewCell else {
                return UITableViewCell()
            }
            cell.stepView.label.text = "\(number)"
            cell.label.text = text
            
            return cell
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UIConstants.headerHeight
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = ServersHeaderView.loadViewFromNib() as ServersHeaderView
        headerView.setName(name: sections[section].title)
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if case TableViewCellModel.tooltip(let text) = sections[indexPath.section].cells[indexPath.row] {
            let attributedText = TooltipTableViewCell.attributedText(for: text)
            let size = CGSize(width: tableView.contentSize.width - tableView.layoutMargins.left - tableView.layoutMargins.right, height: .greatestFiniteMagnitude)
            let boundingRect = attributedText.boundingRect(with: size, options: [.usesLineFragmentOrigin], context: nil)
            return ceil(boundingRect.size.height) + tableView.layoutMargins.top + tableView.layoutMargins.bottom
        } else if case TableViewCellModel.instructionStep(number: _, text: _) = sections[indexPath.section].cells[indexPath.row] {
            return -1 // allows for self sizing
        } else {
            return UIConstants.cellHeight
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = sections[indexPath.section].cells[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)
        
        switch cellModel {
        case .standard:
            guard let cell = cell as? StandardTableViewCell else { return }
            
            cell.select()
        default:
            return
        }
    }
    
    // prevents separators showing on the background (below the last row)
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let sectionCount = numberOfSections(in: tableView)
        if section == sectionCount - 1 {
            return 0.1
        }
        
        return 0
    }
}
