//
//  Created on 26/09/2022.
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

import XCTest
@testable import LegacyCommon
import LegacyCommonTestSupport

class AnnouncementTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testAnnouncementFullScreenImage() async {
        let sources: [FullScreenImage.Source] = [.init(url: "www.example.com", type: "", width: nil, height: nil),
                                                 .init(url: "www.example2.com", type: "", width: nil, height: nil)]
        let fullScreenImage = FullScreenImage(source: sources, alternativeText: "")
        let offerButton = OfferButton(url: "", text: "", action: .openURL, behaviors: [.autoLogin])
        let offerPanel = OfferPanel(fullScreenImage: fullScreenImage,
                                    button: offerButton)
        let offer = Offer(label: "",
                          icon: "",
                          panel: offerPanel)
        let sut = Announcement(notificationID: "someID",
                               startTime: .distantPast,
                               endTime: .distantFuture,
                               type: .default,
                               offer: offer)

        // Recognizes that it is a full screen image mode
        XCTAssertNotNil(sut.fullScreenImage)
        // Takes the first resource from the list
        XCTAssertEqual(sut.prefetchableImage?.absoluteString, "www.example.com")

        let e = expectation(description: "Correctly reports prefetched assets")
        ImageCacheMock.completionBlockParameterValue = true
        var isPrefetched = await sut.isImagePrefetched(imageCache: ImageCacheFactoryMock())
        if isPrefetched {
            e.fulfill()
        }
        await waitForExpectations(timeout: 0.1)

        let e2 = expectation(description: "Correctly reports not prefetched assets")
        ImageCacheMock.completionBlockParameterValue = false
        isPrefetched = await sut.isImagePrefetched(imageCache: ImageCacheFactoryMock())
        if !isPrefetched {
            e2.fulfill()
        }
        await waitForExpectations(timeout: 0.1)
    }
}
