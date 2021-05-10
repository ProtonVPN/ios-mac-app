//
//  ReconnectingOverlayViewModel.swift
//  ProtonVPN - Created on 19/11/2020.
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

import vpncore

class ReconnectingOverlayViewModel: ConnectingOverlayViewModel {
    override var secondString: NSAttributedString {
        if timedOut { return super.secondString }
        switch appState {
        case .connected, .error, .disconnected:
            return super.secondString
        default:
            return (LocalizedString.qsReestablishingConnection + "\n\n" + LocalizedString.qsYourIpWillNotBeExposed)
            .attributed(withColor: .protonWhite(), fontSize: 20)
        }
    }
    
    override var firstString: NSAttributedString {
        switch appState {
        case .connected:
            return LocalizedString.successfullyConnected.attributed(withColor: .protonWhite(), fontSize: 12)
        default:
            return LocalizedString.qsApplyingSettings.attributed(withColor: .white, fontSize: 15)
        }
    }
}
