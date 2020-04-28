//
//  TroubleshootViewModel.swift
//  ProtonVPN - Created on 2020-04-23.
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
import vpncore

public protocol TroubleshootViewModelFactory {
    func makeTroubleshootViewModel() -> TroubleshootViewModel
}

extension DependencyContainer: TroubleshootViewModelFactory {
    func makeTroubleshootViewModel() -> TroubleshootViewModel {
        return TroubleshootViewModel()
    }
}

public struct TroubleshootItem {
    
    public var title: String
    public var description: NSAttributedString
    public var hasSwitch = false
    
}

public class TroubleshootViewModel {
    
    // Data
    public var items: [TroubleshootItem] = [TroubleshootItem]()
    
    init() {
        fillItems()
    }
    
    // MARK: - Callbacks
    
    var cancelled: (() -> Void)?
    
    func cancel() {
        cancelled?()
    }
    
    // MARK: - Data
    
    private let supportEmail = "support@protonmail.com"
    private let urlAlternative = "http://protonmail.com/blog/anti-censorship-alternative-routing"
    private let urlTor = "https://www.torproject.org"
    private let urlProtonStatus = "http://protonstatus.com"
    private let urlSupportForm = "https://protonmail.com/support-form"
    private let urlTwitter = "https://twitter.com/ProtonMail"
    
    private func fillItems() {
        items = [TroubleshootItem]()
        
        // Alternative routing
//        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleAlternative,
//                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootItemDescriptionAlternative)
//                                        .add(link: LocalizedString.troubleshootItemLinkAlternative1, withUrl: urlAlternative), hasSwitch: true))
        
        // No internet
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleNoInternet,
                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionNoInternet)))
        
        // ISP
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleISP,
                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionISP)
                                        .add(link: LocalizedString.troubleshootItemLinkISP1, withUrl: urlTor)))
        
        // ISP
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleGovernment,
                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionGovernment)
                                        .add(link: LocalizedString.troubleshootItemLinkGovernment1, withUrl: urlTor)))
        
        // Antivirus
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleAntivirus,
                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionAntivirus)))
        
        // Proxy / Firewall
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleProxy,
                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionProxy)))
        
        // Proton status
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleProton,
                                      description: NSMutableAttributedString(string: LocalizedString.troubleshootDescriptionProton)
                                        .add(link: LocalizedString.troubleshootItemLinkProton1, withUrl: urlProtonStatus)))
        
        // Contact / Other
        items.append(TroubleshootItem(title: LocalizedString.troubleshootItemTitleOther,
                                      description: NSMutableAttributedString(string: String(format: LocalizedString.troubleshootDescriptionOther, supportEmail))
                                        .add(links: [
                                            (LocalizedString.troubleshootItemLinkOther1, urlSupportForm),
                                            (LocalizedString.troubleshootItemLinkOther2, String(format: "mailto:%@", supportEmail)),
                                            (LocalizedString.troubleshootItemLinkOther3, urlTwitter)
                                        ])))
        
    }
    
}
