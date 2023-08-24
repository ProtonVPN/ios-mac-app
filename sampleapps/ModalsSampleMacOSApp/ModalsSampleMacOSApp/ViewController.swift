//
//  Created on 16/02/2022.
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

import Cocoa
import Modals
import Modals_macOS

class ViewController: NSViewController {

    enum Modal {
        case upsell(UpsellType)
        case discourageSecureCore
    }

    let modals: [(type: Modal, title: String)] = [(.upsell(.allCountries(numberOfServers: 1300,
                                                                         numberOfCountries: 61)), "All countries"),
                                                  (.upsell(.country(country: "PL",
                                                                    numberOfDevices: 10,
                                                                    numberOfCountries: 61)), "Countries"),
                                                  (.upsell(.secureCore), "Secure Core"),
                                                  (.upsell(.netShield), "Net Shield"),
                                                  (.upsell(.safeMode), "Safe Mode"),
                                                  (.upsell(.moderateNAT), "Moderate NAT"),
                                                  (.upsell(.vpnAccelerator), "VPN Accelerator"),
                                                  (.upsell(.customization), "Customization"),
                                                  (.upsell(.profiles), "Profiles"),
                                                  (.discourageSecureCore, "Discourage Secure Core")]

    @IBOutlet weak var tableView: NSTableView! {
        didSet {
            tableView.delegate = self
            tableView.dataSource = self
        }
    }
}

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let modal = modals[row]
        let viewController: NSViewController
        switch modal.type {
        case .upsell(let type):
            viewController = ModalsFactory.upsellViewController(upsellType: type, upgradeAction: { }, learnMoreAction: { })
        case .discourageSecureCore:
            viewController = ModalsFactory.discourageSecureCoreViewController(onDontShowAgain: nil, onActivate: nil, onCancel: nil, onLearnMore: nil)
        }

        presentAsModalWindow(viewController)
        return true
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        modals.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let modal = modals[row]

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ModalNameCellView"), owner: nil) as? NSTableCellView {
              cell.textField?.stringValue = modal.title
              return cell
            }
        return nil
    }
}
