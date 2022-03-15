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

import Foundation
import Cocoa
import vpncore

final class TroubleshootingPopup: NSViewController {

    // MARK: Outlets

    @IBOutlet private weak var tableView: NSTableView!

    // MARK: Properties

    private let cellIdentifier = "TroubleshootingRowItem"
    private var modelCell: TroubleshootingRowItem?

    var viewModel: TroubleshootViewModel?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupData()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyModalAppearance(withTitle: LocalizedString.troubleshootTitle)
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = .cgColor(.background, .weak)
        tableView.backgroundColor = NSColor.protonGrey()
    }

    private func setupData() {
        if #available(OSX 10.13, *) {
            tableView.usesAutomaticRowHeights = true
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(NSNib(nibNamed: NSNib.Name(cellIdentifier), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier))
    }
}

// MARK: Table view delegate

extension TroubleshootingPopup: NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel?.items.count ?? 0
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
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

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
}

// MARK: Table view data source

extension TroubleshootingPopup: NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rowItem = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as! TroubleshootingRowItem
        rowItem.item = viewModel!.items[row]
        return rowItem
    }
}
