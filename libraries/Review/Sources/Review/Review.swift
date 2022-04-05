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
    private var configuration: Configuration
    private var plan: String?

    private let dateProvider: () -> Date
    private let reviewPrompt: ReviewPrompt
    private let dataStorage: ReviewDataStorage
    private let logger: ((String) -> Void)?

    public convenience init(configuration: Configuration, plan: String?, logger: @escaping (String) -> Void) {
        self.init(configuration: configuration, plan: plan, dateProvider: { Date() }, reviewPrompt: AppStoreReviewPrompt(), dataStorage: UserDefaultsReviewDataStorage(), logger: logger)
    }

    init(configuration: Configuration, plan: String?, dateProvider: @escaping () -> Date, reviewPrompt: ReviewPrompt, dataStorage: ReviewDataStorage, logger: ((String) -> Void)? = nil) {
        self.configuration = configuration
        self.plan = plan
        self.dateProvider = dateProvider
        self.reviewPrompt = reviewPrompt
        self.dataStorage = dataStorage
        self.logger = logger
    }

    public func connected() {
        if dataStorage.firstSuccessConnectionStartTimestamp == nil {
            logger?("Saving first successful connection timestamp")
            dataStorage.firstSuccessConnectionStartTimestamp = dateProvider()
        }

        if dataStorage.activeConnectionStartTimestamp == nil {
            logger?("Saving new active connection timestamp and incrementing successful connections count")
            dataStorage.activeConnectionStartTimestamp = dateProvider()
            dataStorage.successConnectionsInARowCount = dataStorage.successConnectionsInARowCount + 1
        }
        checkConditions()
    }

    public func disconnect() {
        guard dataStorage.activeConnectionStartTimestamp != nil else {
            return
        }

        logger?("Resetting active connection timestamp because of disconnection")
        dataStorage.activeConnectionStartTimestamp = nil
    }

    public func connectionFailed() {
        logger?("Resetting successful connections count and active connection timestamp because of failure")
        dataStorage.activeConnectionStartTimestamp = nil
        dataStorage.successConnectionsInARowCount = 0
    }

    public func update(configuration: Configuration) {
        guard self.configuration != configuration else {
            return
        }

        logger?("Review configuration updated")
        self.configuration = configuration
    }

    public func update(plan: String) {
        guard self.plan != plan else {
            return
        }

        logger?("Review user plan updated to \(plan)")
        self.plan = plan
    }

    public func activated() {
        checkConditions()
    }

    public func clear() {
        logger?("Clearing all review data")
        plan = nil
        dataStorage.clear()
    }

    private func show() {
        logger?("Showing review prompt and saving last review timestamp")
        dataStorage.lastReviewShownTimestamp = dateProvider()
        reviewPrompt.show()
    }

    private func checkConditions() {
        // all the conditions require the users plan to be in the eligible list
        guard let plan = plan, configuration.eligiblePlans.contains(plan) else {
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

        /*
         FR-1. Rating after X successful connections

         All the following conditions must be true in order to show the review modal:

             VPN connection successful
             the number of successful connections in a row >= rating_success_connections
             the number of days since the last review modal >= rating_days_last_review_passed
             user's subscription is in rating_eligible_plans
         */
        if dataStorage.successConnectionsInARowCount >= configuration.successConnections {
            logger?("Review conditions met \(dateProvider().timeIntervalSince(firstSuccessConnectionStartTimestamp).days) after first successful connection for plan \(plan) with \(dataStorage.successConnectionsInARowCount) successful connections in a row")
            show()
            return
        }

        /*
         FR-2. Rating after X days connected

         When the app goes in foreground, the following conditions must be true in order to show the review modal:

             VPN is connected
             VPN session length (in days) >= rating_days_connected
             user's subscription is in rating_eligible_plans
         */
        if let activeConnectionStartTimestamp = dataStorage.activeConnectionStartTimestamp, activeConnectionStartTimestamp.addingTimeInterval(TimeInterval(configuration.daysConnected * 60 * 60 * 24)) <= dateProvider() {
            logger?("Review conditions met \(dateProvider().timeIntervalSince(firstSuccessConnectionStartTimestamp).days) after first successful connection for plan \(plan) with session length of \(dateProvider().timeIntervalSince(activeConnectionStartTimestamp).days)")
            show()
            return
        }
    }
}
