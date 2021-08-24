//
//  EnvironmentsViewController.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 24.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit
import vpncore

#if !RELEASE
protocol EnvironmentsViewControllerDelegate: AnyObject {
    func userDidSelectEndpoint(endpoint: String)
}

final class EnvironmentsViewController: UITableViewController {
    weak var delegate: EnvironmentsViewControllerDelegate?

    private let endpoints: [String]

    init(endpoints: [String]) {
        self.endpoints = endpoints

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Endpoint"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return endpoints.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") ?? UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "Cell")
        cell.textLabel?.text = endpoints[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.userDidSelectEndpoint(endpoint: endpoints[indexPath.row])
    }
}
#endif
