//
//  PlanService.swift
//  vpncore - Created on 01.09.2021.
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

import Foundation
import ProtonCoreDataModel
import ProtonCorePayments
import CommonNetworking
import LegacyCommon

class UserCachedStatus: ServicePlanDataStorage {
    var servicePlansDetails: [Plan]?
    var defaultPlanDetails: Plan?
    var currentSubscription: Subscription?
    var credits: Credits?
    var paymentMethods: [PaymentMethod]?
    var paymentsBackendStatusAcceptsIAP: Bool = false
}

class AlertManager: AlertManagerProtocol {
    var title: String?
    var message: String = ""
    var confirmButtonTitle: String?
    var cancelButtonTitle: String?
    var confirmButtonStyle: AlertActionStyle = .default
    var cancelButtonStyle: AlertActionStyle = .default
    func showAlert(confirmAction: ActionCallback, cancelAction: ActionCallback) { }
}
