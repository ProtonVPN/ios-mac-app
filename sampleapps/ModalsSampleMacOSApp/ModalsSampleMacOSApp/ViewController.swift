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
        case whatsNew
        case freeConnections([(String, Image?)])
    }

    let modals: [(type: Modal, title: String)] = [
        (.whatsNew, "What's new"),
        (.upsell(.allCountries(numberOfServers: 1300,
                               numberOfCountries: 61)), "All countries"),
        (.upsell(.country(countryFlag: NSImage(named: "flags_PL")!,
                          numberOfDevices: 10,
                          numberOfCountries: 61)), "Countries"),
        (.upsell(.secureCore), "Secure Core"),
        (.upsell(.netShield), "Net Shield"),
        (.upsell(.safeMode), "Safe Mode"),
        (.upsell(.moderateNAT), "Moderate NAT"),
        (.upsell(.vpnAccelerator), "VPN Accelerator"),
        (.upsell(.customization), "Customization"),
        (.upsell(.profiles), "Profiles"),
        (.discourageSecureCore, "Discourage Secure Core"),
        (.upsell(.cantSkip(
            before: Date().addingTimeInterval(10),
            duration: 10,
            longSkip: false)
        ), "Server Roulette"),
        (.upsell(.cantSkip(
            before: Date().addingTimeInterval(10),
            duration: 10,
            longSkip: true)
        ), "Server Roulette (Too many skips)"),
        (.freeConnections([
            ("Japan", NSImage(named: "flags_JP")!),
            ("Netherlands", NSImage(named: "flags_NL")!),
            ("Romania", NSImage(named: "flags_RO")!),
            ("United States", NSImage(named: "flags_US")!),
            ("Poland", NSImage(named: "flags_PL")!),
        ]), "Feee servers"),
    ]

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
            viewController = ModalsFactory.upsellViewController(upsellType: type, upgradeAction: { }, continueAction: { })
        case .discourageSecureCore:
            viewController = ModalsFactory.discourageSecureCoreViewController(onDontShowAgain: nil, onActivate: nil, onCancel: nil, onLearnMore: nil)
        case .freeConnections(let countries):
            viewController = ModalsFactory.freeConnectionsViewController(countries: countries, upgradeAction: {
                debugPrint(".freeConnections pressed")
            })
        case .whatsNew:
            viewController = ModalsFactory.whatsNewViewController()
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
