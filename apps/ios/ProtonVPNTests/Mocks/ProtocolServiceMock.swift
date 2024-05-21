//
//  ProtocolServiceMock.swift
//  ProtonVPN - Created on 27.09.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import LegacyCommon

@testable import ProtonVPN

class ProtocolServiceMock: ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController {
        return VpnProtocolViewController(viewModel: .init(connectionProtocol: .vpnProtocol(.ike), featureFlags: .init()))
    }
}
