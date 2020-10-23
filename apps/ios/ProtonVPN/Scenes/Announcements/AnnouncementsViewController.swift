//
//  AnnouncementsViewController.swift
//  ProtonVPN - Created on 2020-10-09.
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

class AnnouncementsViewController: UIViewController {

    // Views
    @IBOutlet weak var tableView: UITableView!
    
    // Data
    public var viewModel: AnnouncementsViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(_ viewModel: AnnouncementsViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: "AnnouncementsViewController", bundle: nil)
        
        self.viewModel.refreshView = { [weak self] in
            self?.refreshView()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
    }
    
    private func setupTableView() {
        tableView.register(AnnouncementCell.nib, forCellReuseIdentifier: AnnouncementCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 61.0
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupView() {
        title = LocalizedString.newsTitle
        view.backgroundColor = .protonDarkGrey()
        tableView.backgroundColor = .protonDarkGrey()
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.protonBlack()
    }
    
    private func refreshView() {
        guard tableView != nil else { return }
        tableView.reloadData()
    }
    
}

// MARK: TableView

extension AnnouncementsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.items[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AnnouncementCell.identifier) as? AnnouncementCell else {
            return UITableViewCell()
        }
        cell.style = item.wasRead ? .read : .unread
        cell.title = item.offer?.label
        cell.imageUrl = item.offer?.icon
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = viewModel.items[indexPath.row]
        viewModel.open(announcement: item)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude // Hide last separator
    }
    
}
