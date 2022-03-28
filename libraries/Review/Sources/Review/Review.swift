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

    private var successConenctionsCount = 0
    private var lastReviewShownTimestamp: Date?
    private var plan: String
    private var newPlanPurchaseTimestamp: Date?
    private var activeConenctionStartTimestamp: Date?

    private let dateProvider: () -> Date
    private let reviewPrompt: ReviewPrompt

    public convenience init(configuration: Configuration, plan: String) {
        self.init(configuration: configuration, plan: plan, dateProvider: { Date() }, reviewPrompt: AppStoreReviewPrompt())
    }

    init(configuration: Configuration, plan: String, dateProvider: @escaping () -> Date, reviewPrompt: ReviewPrompt) {
        self.configuration = configuration
        self.plan = plan
        self.dateProvider = dateProvider
        self.reviewPrompt = reviewPrompt
    }

    public func connected() {
        activeConenctionStartTimestamp = dateProvider()
        successConenctionsCount = successConenctionsCount + 1
        checkConditions()
    }

    public func disconnect() {
        activeConenctionStartTimestamp = nil
    }

    public func connectionFailed() {
        activeConenctionStartTimestamp = nil
        successConenctionsCount = 0
    }

    public func planPurchased(plan: String) {
        self.plan = plan
        newPlanPurchaseTimestamp = dateProvider()
    }

    public func activated() {
        checkConditions()
    }

    private func show() {
        newPlanPurchaseTimestamp = nil
        successConenctionsCount = 0
        lastReviewShownTimestamp = dateProvider()
        reviewPrompt.show()
    }

    private func checkConditions() {
        // all the conditions require the users plan to be in the eligible list
        guard configuration.eligiblePlans.contains(plan) else {
            return
        }

        // never show the rating again before the time limit passes no matter which conditions is matched
        // this prevents situations like showing the rating on app activation multiple times if the user is connected for X days (FR-2)
        if let lastReviewShownTimestamp = lastReviewShownTimestamp, lastReviewShownTimestamp.addingTimeInterval(TimeInterval(configuration.daysLastReviewPassed * 60 * 60 * 24)) > dateProvider() {
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
        if successConenctionsCount >= configuration.successConnections {
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
        if let activeConenctionStartTimestamp = activeConenctionStartTimestamp, activeConenctionStartTimestamp.addingTimeInterval(TimeInterval(configuration.daysConnected * 60 * 60 * 24)) <= dateProvider() {
            show()
            return
        }

        /**
         FR-3. Rating after successful connection after payment

         When an in-app purchase is performed and completed, the following conditions must be true in order to show the review modal:

             VPN is connected
             purchase was successful
             user's subscription is in rating_eligible_plans
         */

        // connected after less than 60 seconds after new plan purchase or purchased while a connection is active
        if let newPlanPurchaseTimestamp = newPlanPurchaseTimestamp, newPlanPurchaseTimestamp.addingTimeInterval(60) > dateProvider(), activeConenctionStartTimestamp != nil {
            show()
            return
        }
    }
}
