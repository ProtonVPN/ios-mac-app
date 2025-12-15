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
    // MARK: Properties

    private let tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.backgroundColor = .clear
        tableView.allowsExpansionToolTips = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.allowsColumnSelection = true
        tableView.allowsMultipleSelection = false
        tableView.rowSizeStyle = .default
        tableView.style = .plain

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "MainColumn"))
        column.width = 448
        column.minWidth = 40
        column.maxWidth = 1000
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        tableView.addTableColumn(column)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.horizontalLineScroll = 17
        scrollView.horizontalPageScroll = 10
        scrollView.verticalLineScroll = 17
        scrollView.verticalPageScroll = 10
        scrollView.usesPredominantAxisScrolling = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Configure the vertical scroller as TransparentBackedScroller
        if let verticalScroller = scrollView.verticalScroller {
            verticalScroller.isHidden = true
        }

        return scrollView
    }()

    private let cellIdentifier = "TroubleshootingRowItem"
    private var modelCell: TroubleshootingRowItem?

    public var viewModel: TroubleshootViewModel?

    // MARK: Setup

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override public func loadView() {
        let mainView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 503))
        mainView.wantsLayer = true

        let roundedView = NSView()
        roundedView.translatesAutoresizingMaskIntoConstraints = false

        mainView.addSubview(roundedView)
        roundedView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            // Rounded view constraints
            roundedView.topAnchor.constraint(equalTo: mainView.topAnchor),
            roundedView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            roundedView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            roundedView.bottomAnchor.constraint(equalTo: mainView.bottomAnchor),

            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: roundedView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: roundedView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: roundedView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: roundedView.bottomAnchor, constant: -8),
        ])

        view = mainView
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

        if modelCell == nil {
            modelCell = TroubleshootingRowItem(frame: .zero)
        }

        guard let cellView = modelCell else {
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
        let identifier = NSUserInterfaceItemIdentifier(rawValue: cellIdentifier)
        let rowItem: TroubleshootingRowItem

        if let reusedView = tableView.makeView(withIdentifier: identifier, owner: nil) as? TroubleshootingRowItem {
            rowItem = reusedView
        } else {
            rowItem = TroubleshootingRowItem(frame: .zero)
            rowItem.identifier = identifier
        }

        rowItem.item = viewModel!.items[row]
        return rowItem
    }
}
