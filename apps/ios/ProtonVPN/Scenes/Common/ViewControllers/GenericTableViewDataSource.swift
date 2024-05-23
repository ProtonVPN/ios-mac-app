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
import LegacyCommon
import Home

enum TableViewCellModel {
    
    case pushStandard(title: String, handler: () -> Void)
    case pushKeyValue(key: String, value: String, icon: UIImage? = nil, handler: () -> Void)
    case pushKeyValueAttributed(key: String, value: NSAttributedString, handler: () -> Void)
    case pushAccountDetails(initials: NSAttributedString,
                            username: NSAttributedString,
                            plan: NSAttributedString,
                            handler: () -> Void)
    case imageSubtitle(title: String, subtitle: String, image: UIImage, handler: () -> Void)
    case imageSubtitleImage(title: String, subtitle: String, leadingImage: UIImage, trailingImage: UIImage, handler: () -> Void)
    case titleTextField(title: String, textFieldText: String, textFieldPlaceholder: String, textFieldDelegate: UITextFieldDelegate)
    case staticKeyValue(key: String, value: String)
    case staticPushKeyValue(key: String, value: String, handler: (() -> Void))
    /// `upsell` is executed when the cell accessory is tapped while in the `PaidFeatureDisplayState.upsell` state
    case upsellableToggle(
        title: String,
        state: () -> PaidFeatureDisplayState,
        upsell: (() -> Void),
        handler: ((Bool, @escaping (Bool) -> Void) -> Void)?
    )
    case button(title: String, accessibilityIdentifier: String?, color: UIColor, handler: (() -> Void) )
    case buttonWithLoadingIndicator(title: String,
                                    accessibilityIdentifier: String?,
                                    color: UIColor,
                                    controller: ButtonWithLoadingIndicatorController)
    case tooltip(text: String)
    case instructionStep(number: Int, text: String)
    case checkmarkStandard(title: String, checked: Bool, enabled: Bool = true, handler: () -> Bool)
    case colorPicker(viewModel: ColorPickerViewModel)
    case invertedKeyValue(key: String, value: String, handler: () -> Void)
    case attributedKeyValue(key: NSAttributedString, value: NSAttributedString, handler: () -> Void)
    case textWithActivityCell(title: String, textColor: UIColor, backgroundColor: UIColor, showActivity: Bool)
    case attributedTooltip(text: NSAttributedString)
    case netShieldStats(viewModel: NetShieldModel)
}

protocol ButtonWithLoadingIndicatorController: AnyObject {
    var startLoading: () -> Void { get set }
    var stopLoading: () -> Void { get set }
    func onPressed()
}

struct TableViewSection {
    let title: String
    var cells: [TableViewCellModel]
    let showHeader: Bool
    let showSeparator: Bool
    
    init(title: String, showHeader: Bool = true, showSeparator: Bool = false, cells: [TableViewCellModel]) {
        self.title = title
        self.cells = cells
        self.showHeader = showHeader
        self.showSeparator = showSeparator
    }
    
    var headerHeight: CGFloat {
        return showHeader ? UIConstants.headerHeight : CGFloat.leastNormalMagnitude
    }
}

// A generic data source for table views
class GenericTableViewDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    var sections: [TableViewSection]
    var onSelectionChange: (() -> Void)?
    
    init(for tableView: UITableView, with sections: [TableViewSection], onSelectionChange: (() -> Void)? = nil) {
        self.sections = sections
        self.onSelectionChange = onSelectionChange
        
        tableView.register(StandardTableViewCell.nib, forCellReuseIdentifier: StandardTableViewCell.identifier)
        tableView.register(TitleTextFieldTableViewCell.nib, forCellReuseIdentifier: TitleTextFieldTableViewCell.identifier)
        tableView.register(KeyValueTableViewCell.nib, forCellReuseIdentifier: KeyValueTableViewCell.identifier)
        tableView.register(SwitchTableViewCell.nib, forCellReuseIdentifier: SwitchTableViewCell.identifier)
        tableView.register(TooltipTableViewCell.nib, forCellReuseIdentifier: TooltipTableViewCell.identifier)
        tableView.register(ButtonTableViewCell.nib, forCellReuseIdentifier: ButtonTableViewCell.identifier)
        tableView.register(InstructionStepTableViewCell.nib, forCellReuseIdentifier: InstructionStepTableViewCell.identifier)
        tableView.register(CheckmarkTableViewCell.nib, forCellReuseIdentifier: CheckmarkTableViewCell.identifier)
        tableView.register(ColorPickerTableViewCell.nib, forCellReuseIdentifier: ColorPickerTableViewCell.identifier)
        tableView.register(TextWithActivityCell.nib, forCellReuseIdentifier: TextWithActivityCell.identifier)
        tableView.register(TextWithActivityCell.nib, forCellReuseIdentifier: TextWithActivityCell.identifier)
        tableView.register(AccountDetailsTableViewCell.nib, forCellReuseIdentifier: AccountDetailsTableViewCell.identifier)
        tableView.register(ButtonWithLoadingTableViewCell.nib, forCellReuseIdentifier: ButtonWithLoadingTableViewCell.identifier)
        tableView.register(ImageSubtitleTableViewCell.nib, forCellReuseIdentifier: ImageSubtitleTableViewCell.identifier)
        tableView.register(ImageSubtitleImageTableViewCell.nib, forCellReuseIdentifier: ImageSubtitleImageTableViewCell.identifier)
        tableView.register(NetShieldStatsTableViewCell.nib, forCellReuseIdentifier: NetShieldStatsTableViewCell.identifier)
    }
    
    public func update(rows: [IndexPath: TableViewCellModel]) {
        for (index, row) in rows {
            sections[index.section].cells[index.row] = row
        }
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
        case .invertedKeyValue(key: let key, value: let value, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
                
            cell.accessoryType = .none
            cell.titleLabel.text = key
            cell.subtitleLabel.text = value
            cell.completionHandler = handler
            cell.invert()
                
            return cell
        case .attributedKeyValue(key: let key, value: let value, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
                
            cell.accessoryType = .none
            cell.titleLabel.attributedText = key
            cell.subtitleLabel.attributedText = value
            cell.completionHandler = handler
                
            return cell
        case .pushStandard(title: let title, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = title
            cell.subtitleLabel.text = nil
            cell.completionHandler = handler

            return cell
        case .pushKeyValue(key: let key, value: let value, icon: let icon, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: StandardTableViewCell.identifier) as? StandardTableViewCell else {
                return UITableViewCell()
            }

            cell.icon = icon
            cell.titleLabel.text = key
            cell.accessibilityIdentifier = key
            cell.subtitleLabel.text = value
            cell.subtitleLabel.accessibilityIdentifier = value
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

        case .imageSubtitle(title: let title, subtitle: let subtitle, image: let image, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ImageSubtitleTableViewCell.identifier) as? ImageSubtitleTableViewCell else {
                return UITableViewCell()
            }

            cell.titleLabel.text = title
            cell.subtitleLabel.text = subtitle
            cell.imageView?.image = image
            cell.selectionHandler = handler

            return cell

        case .imageSubtitleImage(title: let title, subtitle: let subtitle, leadingImage: let leadingImage, trailingImage: let trailingImage, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ImageSubtitleImageTableViewCell.identifier) as? ImageSubtitleImageTableViewCell else {
                return UITableViewCell()
            }

            cell.titleLabel.text = title
            cell.subtitleLabel.text = subtitle
            cell.leadingImageView?.image = leadingImage
            cell.trailingImageView?.image = trailingImage
            cell.selectionHandler = handler

            return cell
        case .titleTextField(title: let title, textFieldText: let textFieldText, textFieldPlaceholder: let textFieldPlaceholder, textFieldDelegate: let delegate):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TitleTextFieldTableViewCell.identifier) as? TitleTextFieldTableViewCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = title
            cell.textField.text = textFieldText
            cell.textField.attributedPlaceholder = textFieldPlaceholder.attributed(withColor: .weakTextColor(), fontSize: 17)
            cell.textField.delegate = delegate
            
            return cell
        case .staticKeyValue(key: let key, value: let value):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: KeyValueTableViewCell.identifier) as? KeyValueTableViewCell else {
                return UITableViewCell()
            }
            cell.viewModel = [key: value]
            
            return cell
        case .staticPushKeyValue(key: let key, value: let value, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: KeyValueTableViewCell.identifier) as? KeyValueTableViewCell else {
                return UITableViewCell()
            }
            cell.viewModel = [key: value]
            cell.completionHandler = handler
            cell.showDisclosure(true)
            
            return cell

        case .upsellableToggle(let title, let state, let upsell, let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.identifier) as? SwitchTableViewCell else {
                return UITableViewCell()
            }
            cell.label.text = title
            cell.setup(with: state())
            cell.upsellTapped = upsell
            cell.toggled = handler
            cell.switchControl.accessibilityLabel = title

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
        case .checkmarkStandard(title: let title, checked: let checked, let enabled, handler: let handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CheckmarkTableViewCell.identifier) as? CheckmarkTableViewCell else {
                return UITableViewCell()
            }
            cell.isEnabled = enabled
            cell.accessibilityIdentifier = title
            cell.label.text = title
            cell.accessoryType = checked ? .checkmark : .none
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
        case .textWithActivityCell(title: let title, textColor: let textColor, backgroundColor: let backgroundColor, showActivity: let showActivity):
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TextWithActivityCell.identifier) as? TextWithActivityCell else {
                return UITableViewCell()
            }
            
            cell.titleLabel.text = title
            cell.titleLabel.textColor = textColor
            cell.activityIndicatorView.color = textColor
            cell.backgroundColor = backgroundColor
            if showActivity {
                cell.activityIndicatorView.startAnimating()
            } else {
                cell.activityIndicatorView.stopAnimating()
            }
            
            return cell
        case let .attributedTooltip(text: attributedText):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TooltipTableViewCell.identifier) as? TooltipTableViewCell else {
                return UITableViewCell()
            }
            cell.tooltipLabel.attributedText = attributedText

            return cell
        
        case let .pushAccountDetails(initials, username, plan, handler):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AccountDetailsTableViewCell.identifier) as? AccountDetailsTableViewCell else {
                return UITableViewCell()
            }
            
            cell.setup(initials: initials, username: username, plan: plan, handler: handler)
            
            return cell
            
        case let .buttonWithLoadingIndicator(title, accessibilityIdentifier, color, controller):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ButtonWithLoadingTableViewCell.identifier) as? ButtonWithLoadingTableViewCell else {
                return UITableViewCell()
            }
            
            cell.setup(title: title, accessibilityIdentifier: accessibilityIdentifier, color: color, controller: controller)
            
            return cell
        case let .netShieldStats(viewModel):
            let reusableCell = tableView.dequeueReusableCell(withIdentifier: NetShieldStatsTableViewCell.identifier)
            guard let cell = reusableCell as? NetShieldStatsTableViewCell else { return reusableCell ?? UITableViewCell() }

            cell.setup(with: viewModel)

            return cell
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sections[section].headerHeight
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = ServersHeaderView.loadViewFromNib() as ServersHeaderView
        headerView.setName(name: sections[section].title)
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section].cells[indexPath.row] {
        case .tooltip, .attributedTooltip:
            return -1 // allows for self sizing
        case .instructionStep:
            return -1 // allows for self sizing
        case .colorPicker(viewModel: let viewModel):
            return viewModel.height
        case .textWithActivityCell:
            return -1 // allows for self sizing
        case .pushAccountDetails:
            return -1
        case .imageSubtitle:
            return -1
        case .imageSubtitleImage:
            return -1
        case .netShieldStats:
            return UITableView.automaticDimension
        default:
            return UIConstants.cellHeight
        }
    }

    // swiftlint:disable cyclomatic_complexity
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellModel = sections[indexPath.section].cells[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath)
        
        switch cellModel {
        case .pushStandard, .pushKeyValue, .pushKeyValueAttributed, .invertedKeyValue, .attributedKeyValue:
            guard let cell = cell as? StandardTableViewCell else { return }
            
            cell.select()
            onSelectionChange?()
        case .checkmarkStandard:
            guard let cell = cell as? CheckmarkTableViewCell else { return }
            
            cell.select()
            onSelectionChange?()
        case .staticPushKeyValue:
            guard let cell = cell as? KeyValueTableViewCell else { return }
            
            cell.select()
            onSelectionChange?()
        case .pushAccountDetails:
            guard let cell = cell as? AccountDetailsTableViewCell else { return }
            
            cell.select()
            onSelectionChange?()
        case .imageSubtitle:
            guard let cell = cell as? ImageSubtitleTableViewCell else { return }

            cell.select()
            onSelectionChange?()
        case .imageSubtitleImage:
            guard let cell = cell as? ImageSubtitleImageTableViewCell else { return }

            cell.select()
            onSelectionChange?()
        default:
            return
        }
    }
    // swiftlint:enable cyclomatic_complexity
    
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
        if sections.indices.contains(section), sections[section].showSeparator {
            return UIConstants.separatorHeight
        }

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
