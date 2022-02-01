//
//  Created on 2022-02-01.
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

import Foundation

public extension BugReportModel {
    static let mock = BugReportModel(categories: [
        Category(label: "Browsing speed",
                 submitLabel: "Submit",
                 suggestions: [
                    Suggestion(text: "Secure Core slows down your connection. Use it only when necessary.", link: nil),
                    Suggestion(text: "Select a server closer to your location.", link: "https://protonvpn.com/faq/choosing_best_server"),
                 ],
                 inputFields: [
                    InputField(label: "Network type",
                               submitLabel: "network",
                               type: .textSingleLine,
                               isMandatory: true,
                               placeholder: "Home, work, Wifi, cellular, etc."),

                    InputField(label: "What are you trying to do",
                               submitLabel: "What do you do",
                               type: .textMultiLine,
                               isMandatory: true,
                               placeholder: "Loerp ipsum"),

                    InputField(label: "What is the speed you are getting?",
                               submitLabel: "Speed",
                               type: .textMultiLine,
                               isMandatory: true,
                               placeholder: "Loerp ipsum speed"),

                    InputField(label: "What is you connection speed without VPN?",
                               submitLabel: "Speed without VPN",
                               type: .textMultiLine,
                               isMandatory: true,
                               placeholder: "Loerp ipsum speed no vpn"),
                 ]),
        Category(label: "Connecting to VPN",
                 submitLabel: "Submit",
                 suggestions: [],
                 inputFields: []),
        Category(label: "Streaming",
                 submitLabel: "Submit",
                 suggestions: [],
                 inputFields: []),
        Category(label: "Something else",
                 submitLabel: "Submit",
                 suggestions: [],
                 inputFields: []),
    ])
}
