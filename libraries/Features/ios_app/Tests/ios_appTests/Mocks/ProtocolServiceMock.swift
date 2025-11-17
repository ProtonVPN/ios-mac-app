//
//  ProtocolServiceMock.swift
//  ProtonVPN - Created on 27.09.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
@testable import ios_app
import LegacyCommon

class ProtocolServiceMock: ProtocolService {
    func makeVpnProtocolViewController(viewModel _: VpnProtocolViewModel) -> VpnProtocolViewController {
        VpnProtocolViewController(viewModel: .init(
            connectionProtocol: .vpnProtocol(.ike),
            smartProtocolConfig: .init(),
            featureFlags: .init()
        ))
    }
}
