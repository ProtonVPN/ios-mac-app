//
//  Created on 15/11/2022.
//
//  Copyright (c) 2022 Proton AG
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

import UIKit
import LegacyCommon
import ProtonCoreUIFoundations
import Strings

class ServersInformationViewController: UIViewController {
    static var identifier: String {
        return String(describing: self)
    }

    struct ViewModel {
        let title: String
        let sections: [Section]
    }

    struct Section {
        let title: String?
        let rowViewModels: [InformationTableViewCell.ViewModel]
    }

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!

    var viewModel: ViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        closeButton.setImage(IconProvider.crossBig, for: .normal)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.bounces = false
        tableView.separatorStyle = .none
        tableView.allowsSelection = false

        view.backgroundColor = .backgroundColor()

        titleLabel.text = Localizable.informationTitle
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textColor = .normalTextColor()
    }

    @IBAction func didTapDismiss(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}

extension ServersInformationViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[section].rowViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: InformationTableViewCell.cellIdentifier,
                                                 for: indexPath)
        guard let informationCell = cell as? InformationTableViewCell else {
            return cell
        }
        let section = viewModel.sections[indexPath.section]
        informationCell.viewModel = section.rowViewModels[indexPath.row]

        return cell
    }
}

extension ServersInformationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        viewModel.sections[section].title != nil ? 56 : 0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .weakTextColor()

        header.addSubview(label)
        header.addConstraints([header.topAnchor.constraint(equalTo: label.topAnchor),
                               header.leftAnchor.constraint(equalTo: label.leftAnchor, constant: -16),
                               header.rightAnchor.constraint(equalTo: label.rightAnchor),
                               header.bottomAnchor.constraint(equalTo: label.bottomAnchor)])
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = viewModel.sections[section].title
        return header
    }
}
