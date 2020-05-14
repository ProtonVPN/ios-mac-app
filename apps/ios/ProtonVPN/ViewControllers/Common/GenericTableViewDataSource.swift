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
    
    case pushStandard(title: String, handler: (() -> Void) )
    case pushKeyValue(key: String, value: String, handler: (() -> Void) )
    case pushKeyValueAttributed(key: String, value: NSAttributedString, handler: (() -> Void) )
    case titleTextField(title: String, textFieldText: String, textFieldPlaceholder: String, textFieldDelegate: UITextFieldDelegate)
    case staticKeyValue(key: String, value: String)
    case toggle(title: String, on: Bool, enabled: Bool, handler: ((Bool) -> Void)? )
    case button(title: String, accessibilityIdentifier: String?, color: UIColor, handler: (() -> Void) )
    case tooltip(text: String)
    case instructionStep(number: Int, text: String)
    case checkmarkStandard(title: String, checked: Bool, handler: (() -> Void) )
    case colorPicker(viewModel: ColorPickerViewModel)
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
        tableView.register(TitleTextFieldTableViewCell.nib, forCellReuseIdentifier: TitleTextFieldTableViewCell.identifier)
        tableView.register(KeyValueTableViewCell.nib, forCellReuseIdentifier: KeyValueTableViewCell.identifier)
        tableView.register(SwitchTableViewCell.nib, forCellReuseIdentifier: SwitchTableViewCell.identifier)
        tableView.register(TooltipTableViewCell.nib, forCellReuseIdentifier: TooltipTableViewCell.identifier)
        tableView.register(ButtonTableViewCell.nib, forCellReuseIdentifier: ButtonTableViewCell.identifier)
        tableView.register(InstructionStepTableViewCell.nib, forCellReuseIdentifier: InstructionStepTableViewCell.identifier)
        tableView.register(CheckmarkTableViewCell.nib, forCellReuseIdentifier: CheckmarkTableViewCell.identifier)
        tableView.register(ColorPickerTableViewCell.nib, forCellReuseIdentifier: ColorPickerTableViewCell.identifier)
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
        case .pushStandard(title: let title, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = title
            cell.subtitleLabel.text = nil
            cell.completionHandler = handler
            
            return cell
        case .pushKeyValue(key: let key, value: let value, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = key
            cell.subtitleLabel.text = value
            cell.completionHandler = handler
            
            return cell
        case .pushKeyValueAttributed(key: let key, value: let value, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = key
            cell.subtitleLabel.attributedText = value
            cell.completionHandler = handler
            
            return cell
        case .titleTextField(title: let title, textFieldText: let textFieldText, textFieldPlaceholder: let textFieldPlaceholder, textFieldDelegate: let delegate):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TitleTextFieldTableViewCell.identifier) as? TitleTextFieldTableViewCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = title
            cell.textField.text = textFieldText
            cell.textField.attributedPlaceholder = textFieldPlaceholder.attributed(withColor: .protonFontLightGrey(), fontSize: 17)
            cell.textField.delegate = delegate
            
            return cell
        case .staticKeyValue(key: let key, value: let value):
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
        case .checkmarkStandard(title: let title, checked: let checked, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CheckmarkTableViewCell.identifier) as? CheckmarkTableViewCell else {
                return UITableViewCell()
            }
            
            cell.label.text = title
            if checked {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            
            cell.completionHandler = handler
            
            return cell
        case .colorPicker(viewModel: let viewModel):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ColorPickerTableViewCell.identifier) as? ColorPickerTableViewCell else {
                return UITableViewCell()
            }
            
            cell.collectionView.dataSource = viewModel
            cell.collectionView.delegate = viewModel
            
            let selectedIndex = IndexPath(row: viewModel.selectedColorIndex, section: 0)
            cell.collectionView.selectItem(at: selectedIndex, animated: false, scrollPosition: .top)
            
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
        switch sections[indexPath.section].cells[indexPath.row] {
        case .tooltip:
            return -1 // allows for self sizing
        case .instructionStep:
            return -1 // allows for self sizing
        case .colorPicker(viewModel: let viewModel):
            return viewModel.height
        default:
            return UIConstants.cellHeight
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = sections[indexPath.section].cells[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)
        
        switch cellModel {
        case .pushStandard, .pushKeyValue, .pushKeyValueAttributed:
            guard let cell = cell as? StandardTableViewCell else { return }
            
            cell.select()
        case .checkmarkStandard:
            guard let cell = cell as? CheckmarkTableViewCell else { return }
            
            cell.select()
        default:
            return
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cellModel = sections[indexPath.section].cells[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)
        
        switch cellModel {
        case .checkmarkStandard:
            guard let cell = cell as? CheckmarkTableViewCell else { return }
            
            cell.deselect()
        default:
            return
        }
    }
    
    // Prevents separators showing on the background (below the last row)
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let sectionCount = numberOfSections(in: tableView)
        if section == sectionCount - 1 {
            return 0.1
        }
        
        return 0
    }
    
    // Prevents separator artifacts showing below the last cell
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let sectionCount = numberOfSections(in: tableView)
        if section == sectionCount - 1 {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIConstants.cellHeight))
            return view
        }
        
        return nil
    }
}
