//
//  ExtensionInfoComparisonTests.swift
//  ProtonVPNmacOSTests
//
//  Created by Jaroslav on 2021-07-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import ProtonVPN
import Testing

struct ExtensionInfoComparisonTests {
    @Test("Equality")
    func equality() {
        #expect(ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id") == ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"))
    }

    @Test("Different versions and builds compare greater")
    func different() {
        #expect(ExtensionInfo(version: "2.1.1", build: "1", bundleId: "id") > ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"))
        #expect(ExtensionInfo(version: "1.1.1", build: "125", bundleId: "id") > ExtensionInfo(version: "1.1.1", build: "1", bundleId: "id"))
    }

    private func info(_ version: String, _ buildNumber: String) -> ExtensionInfo {
        ExtensionInfo(version: version, build: buildNumber, bundleId: "me.proton.jetpack")
    }

    @Test("compare(to:) reports orderedSame")
    func equals() {
        let info1 = info("1.2.3", "202030.1210311620")
        let info2 = info("1.2.3", "202030.1210311620")

        #expect(info1.compare(to: info2) == .orderedSame)
    }

    @Test("Less-than ordering across version/build formats")
    func lessThan() {
        do {
            let info1 = info("1.2.3", "1210311620")
            let info2 = info("1.2.4", "1210311620")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1234567.1210311620")
            let info2 = info("1.2.4", "1210311620")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1234568.1210311620")
            let info2 = info("1.2.4", "1234567.1210311622")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1210311620")
            let info2 = info("1.2.3", "1210311621")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1234567.1210311620")
            let info2 = info("1.2.3", "1234567.1210311621")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1234567.1210311620")
            let info2 = info("1.2.3", "1234568.1210311620")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1234567.1210311622")
            let info2 = info("1.2.3", "1234568.1210311620")
            #expect(info1 < info2)
        }

        do {
            let info1 = info("1.2.3", "1234567")
            let info2 = info("1.2.3", "1234567.1210311620")
            #expect(info1 < info2)
        }
    }
}
