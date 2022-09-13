//
//  Created on 2022-05-23.
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
import PMLogger

/// For WireGuard on iOS, if the app is connected to WireGuard at the moment when we want to get the logs, we should first ask WG NE to flush the logs to a file. 
/// After that we can proceed as if it's a simple log file.
class WGiOSLogContent: LogContent {

    private var fileLogContent: FileLogContent
    private var wireguardProtocolFactory: WireguardProtocolFactory

    init(fileLogContent: FileLogContent, wireguardProtocolFactory: WireguardProtocolFactory) {
        self.fileLogContent = fileLogContent
        self.wireguardProtocolFactory = wireguardProtocolFactory
    }

    func loadContent(callback: @escaping (String) -> Void) {
        // We don't care if flush succeeded or not. In case NE is not up and runnning it means latest logs were already saved to file.
        wireguardProtocolFactory.flushLogs { _ in
            self.fileLogContent.loadContent(callback: callback)
        }
    }

}
