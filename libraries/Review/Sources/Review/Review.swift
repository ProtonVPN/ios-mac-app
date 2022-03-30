//
//  Created on 28.03.2022.
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

public final class Review {
    private let configuration: Configuration
    private var plan: String

    private let dateProvider: () -> Date
    private let reviewPrompt: ReviewPrompt
    private let dataStorage: ReviewDataStorage

    public convenience init(configuration: Configuration, plan: String) {
        self.init(configuration: configuration, plan: plan, dateProvider: { Date() }, reviewPrompt: AppStoreReviewPrompt(), dataStorage: UserDefaultsReviewDataStorage())
    }

    init(configuration: Configuration, plan: String, dateProvider: @escaping () -> Date, reviewPrompt: ReviewPrompt, dataStorage: ReviewDataStorage) {
        self.configuration = configuration
        self.plan = plan
        self.dateProvider = dateProvider
        self.reviewPrompt = reviewPrompt
        self.dataStorage = dataStorage
    }

    public func connected() {
        print("Connected invoked")
        if dataStorage.firstSuccessConnectionStartTimestamp == nil {
            print("Setting first conenction timestamp")
            dataStorage.firstSuccessConnectionStartTimestamp = dateProvider()
        }

        if dataStorage.activeConnectionStartTimestamp == nil {
            print("Setting active conenction timestamp")
            dataStorage.activeConnectionStartTimestamp = dateProvider()
            dataStorage.successConnenctionsInARowCount = dataStorage.successConnenctionsInARowCount + 1
        }
        checkConditions()
    }

    public func disconnect() {
        print("Disconencted invoked, resetting active connection timestamp")
        dataStorage.activeConnectionStartTimestamp = nil
    }

    public func connectionFailed() {
        print("Failed invoked, resetting active connection timestamp and success count")
        dataStorage.activeConnectionStartTimestamp = nil
        dataStorage.successConnenctionsInARowCount = 0
    }

    public func planUpdated(plan: String) {
        print("Plan changed to \(plan)")
        self.plan = plan
    }

    public func activated() {
        print("App activated")
        checkConditions()
    }

    public func clear() {
        dataStorage.clear()
    }

    private func show() {
        dataStorage.lastReviewShownTimestamp = dateProvider()
        reviewPrompt.show()
    }

    private func checkConditions() {
        // all the conditions require the users plan to be in the eligible list
        guard configuration.eligiblePlans.contains(plan) else {
            return
        }

        // all the conditions require that sufficient time passed since first successful connection
        guard let firstSuccessConnectionStartTimestamp = dataStorage.firstSuccessConnectionStartTimestamp, firstSuccessConnectionStartTimestamp.addingTimeInterval(TimeInterval(configuration.daysFromFirstConnection * 60 * 60 * 24)) < dateProvider() else {
            return
        }

        // never show the rating again before the time limit passes no matter which conditions is matched
        // this prevents situations like showing the rating on app activation multiple times if the user is connected for X days (FR-2)
        if let lastReviewShownTimestamp = dataStorage.lastReviewShownTimestamp, lastReviewShownTimestamp.addingTimeInterval(TimeInterval(configuration.daysLastReviewPassed * 60 * 60 * 24)) > dateProvider() {
            return
        }

        /**
         FR-1. Rating after X successful connections

         All the following conditions must be true in order to show the review modal:

             VPN connection successful
             the number of successful connections in a row >= rating_success_connections
             the number of days since the last review modal >= rating_days_last_review_passed
             user's subscription is in rating_eligible_plans
         */
        if dataStorage.successConnenctionsInARowCount >= configuration.successConnections {
            show()
            return
        }

        /**
         FR-2. Rating after X days connected

         When the app goes in foreground, the following conditions must be true in order to show the review modal:

             VPN is connected
             VPN session length (in days) >= rating_days_connected
             user's subscription is in rating_eligible_plans
         */
        if let activeConenctionStartTimestamp = dataStorage.activeConnectionStartTimestamp, activeConenctionStartTimestamp.addingTimeInterval(TimeInterval(configuration.daysConnected * 60 * 60 * 24)) <= dateProvider() {
            show()
            return
        }
    }
}
