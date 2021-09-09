//
//  ProtocolServiceMock.swift
//  ProtonVPN - Created on 27.09.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import vpncore

class ProtocolServiceMock: ProtocolService {
    func makeVpnProtocolViewController(viewModel: VpnProtocolViewModel) -> VpnProtocolViewController {
        return VpnProtocolViewController(viewModel: VpnProtocolViewModel(connectionProtocol: .vpnProtocol(.ike), featureFlags: FeatureFlags(), alertService: CoreAlertServiceMock()))
    }
}
