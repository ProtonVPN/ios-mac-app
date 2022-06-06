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

public protocol LogContentProviderFactory {
    func makeLogContentProvider() -> LogContentProvider
}

public protocol LogContentProvider {
    func getLogData(for source: LogSource) -> LogContent
}

#if os(iOS)
/// Create and return a proper LogData implementation for a given log source
public class IOSLogContentProvider: LogContentProvider {

    private let folder: URL
    private let appGroup: String
    private let wireguardProtocolFactory: WireguardProtocolFactory

    public init(appLogsFolder folder: URL, appGroup: String, wireguardProtocolFactory: WireguardProtocolFactory) {
        self.folder = folder
        self.appGroup = appGroup
        self.wireguardProtocolFactory = wireguardProtocolFactory
    }

    public func getLogData(for source: LogSource) -> LogContent {
        switch source {
        case .app:
            return AppLogContent(folder: folder)

        case .osLog:
            guard #available(iOS 15, *) else {
                return EmptyLogContent()
            }
            return OSLogContent()

        case .openvpn:
            let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) ?? FileManager.default.temporaryDirectory
            return FileLogContent(file: folder.appendingPathComponent(CoreAppConstants.LogFiles.openVpn))

        case .wireguard:
            let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) ?? FileManager.default.temporaryDirectory
            return WGiOSLogContent(fileLogContent: FileLogContent(file: folder.appendingPathComponent(CoreAppConstants.LogFiles.wireGuard)), wireguardProtocolFactory: wireguardProtocolFactory)
        }
    }

}

#elseif os(macOS)

/// Create and return a proper LogData implementation for a given log source
public class MacOSLogContentProvider: LogContentProvider {

    private let folder: URL
    private let wireguardProtocolFactory: WireguardProtocolFactory
    private let openVpnProtocolFactory: OpenVpnProtocolFactory

    public init(appLogsFolder folder: URL, wireguardProtocolFactory: WireguardProtocolFactory, openVpnProtocolFactory: OpenVpnProtocolFactory) {
        self.folder = folder
        self.wireguardProtocolFactory = wireguardProtocolFactory
        self.openVpnProtocolFactory = openVpnProtocolFactory
    }

    public func getLogData(for source: LogSource) -> LogContent {
        switch source {
        case .app:
            return AppLogContent(folder: folder)

        case .osLog:
            guard #available(macOS 12, *) else {
                return EmptyLogContent()
            }
            return OSLogContent()

        case .openvpn:
            return NELogContent(protocolFactory: openVpnProtocolFactory)

        case .wireguard:
            return NELogContent(protocolFactory: wireguardProtocolFactory)
            
        }
    }

}
#endif
