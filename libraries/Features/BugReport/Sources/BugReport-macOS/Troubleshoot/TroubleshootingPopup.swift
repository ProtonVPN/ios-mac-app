//
//  TroubleshootingPopup.swift
//  ProtonVPN - Created on 26.02.2021.
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

import BugReportShared
import Cocoa
import Ergonomics
import Foundation
import Strings

public final class TroubleshootingPopup: NSViewController {
    // MARK: Outlets

    @IBOutlet private var tableView: NSTableView!

    // MARK: Properties

    private let cellIdentifier = "TroubleshootingRowItem"
    private var modelCell: TroubleshootingRowItem?

    public var viewModel: TroubleshootViewModel?

    // MARK: Setup

    public init() {
        super.init(nibName: String(describing: TroubleshootingPopup.self), bundle: Bundle.module)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupData()
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: Localizable.troubleshootTitle)
    }

    private func setupUI() {
        view.wantsLayer = true
        DarkAppearance {
            let backgroundColor: NSColor = .color(.background)
            view.layer?.backgroundColor = backgroundColor.cgColor
            tableView.backgroundColor = backgroundColor
        }
    }

    private func setupData() {
        tableView.usesAutomaticRowHeights = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(NSNib(nibNamed: NSNib.Name(cellIdentifier), bundle: Bundle.module), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier))
    }
}

// MARK: Table view delegate

extension TroubleshootingPopup: NSTableViewDelegate {
    public func numberOfRows(in _: NSTableView) -> Int {
        viewModel?.items.count ?? 0
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard let model = viewModel?.items[row] else {
            return 0
        }

        guard let cellView = modelCell ?? tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? TroubleshootingRowItem else {
            return 0
        }

        cellView.item = model

        cellView.bounds.size.width = tableView.bounds.size.width
        cellView.needsLayout = true
        cellView.layoutSubtreeIfNeeded()

        let height = cellView.fittingSize.height + 12
        return height > tableView.rowHeight ? height : tableView.rowHeight
    }

    public func tableView(_: NSTableView, shouldSelectRow _: Int) -> Bool {
        false
    }
}

// MARK: Table view data source

extension TroubleshootingPopup: NSTableViewDataSource {
    public func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let rowItem = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as! TroubleshootingRowItem
        rowItem.item = viewModel!.items[row]
        return rowItem
    }
}
