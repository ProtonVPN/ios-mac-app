//
//  VpnProperties.swift
//  vpncore - Created on 06/05/2020.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import ProtonCoreDataModel

public struct VpnProperties {
    
    public let serverModels: [ServerModel]
    public let vpnCredentials: VpnCredentials
    public let location: UserLocation?
    public let clientConfig: ClientConfig?
    public let userRole: UserRole
    public let userCreateTime: Date?
    public let userAccountRecovery: AccountRecovery?
    public let userInfo: UserInfo?

    public init(
        serverModels: [ServerModel],
        vpnCredentials: VpnCredentials,
        location: UserLocation?,
        clientConfig: ClientConfig?,
        user: User?,
        addresses: [Address]?
    ) {
        self.serverModels = serverModels
        self.vpnCredentials = vpnCredentials
        self.location = location
        self.clientConfig = clientConfig
        self.userRole = .init(rawValue: user?.role ?? 0) ?? .noOrganization
        self.userAccountRecovery = user?.accountRecovery
        self.userInfo = Self.buildUserInfo(user: user, addresses: addresses)
        if let createTime = user?.createTime {
            self.userCreateTime = Date(timeIntervalSince1970: createTime)
        } else {
            self.userCreateTime = nil
        }
    }

    private static func buildUserInfo(user: User?, addresses: [Address]?) -> UserInfo? {
        guard let user, let addresses else { return nil }
        return UserInfo(
            displayName: user.displayName,
            hideEmbeddedImages: nil,
            hideRemoteImages: nil,
            imageProxy: nil,
            maxSpace: user.maxSpace,
            maxBaseSpace: user.maxBaseSpace,
            maxDriveSpace: user.maxDriveSpace,
            notificationEmail: nil,
            signature: nil,
            usedSpace: user.usedSpace,
            usedBaseSpace: user.usedBaseSpace,
            usedDriveSpace: user.usedDriveSpace,
            userAddresses: addresses,
            autoSC: nil,
            language: nil,
            maxUpload: user.maxUpload,
            notify: nil,
            swipeLeft: nil,
            swipeRight: nil,
            role: user.role,
            delinquent: user.delinquent,
            keys: user.keys,
            userId: user.ID,
            sign: nil,
            attachPublicKey: nil,
            linkConfirmation: nil,
            credit: user.credit,
            currency: user.currency,
            createTime: user.createTime == nil ? nil : Int64(user.createTime!),
            pwdMode: nil,
            twoFA: nil,
            enableFolderColor: nil,
            inheritParentFolderColor: nil,
            subscribed: user.subscribed,
            groupingMode: nil,
            weekStart: nil,
            delaySendSeconds: nil,
            telemetry: nil,
            crashReports: nil,
            conversationToolbarActions: nil,
            messageToolbarActions: nil,
            listToolbarActions: nil,
            referralProgram: nil
        )
    }
}
