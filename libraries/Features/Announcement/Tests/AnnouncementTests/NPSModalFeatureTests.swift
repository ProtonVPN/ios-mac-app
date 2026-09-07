//
//  Created on 2026-08-26 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

@testable import Announcement
import ComposableArchitecture
import Testing

@MainActor
@Suite("NPSModalFeature")
struct NPSModalFeatureTests {
    @Test("Modal opens with nothing selected, no comment field and submission disabled")
    func initialState() {
        let state = NPSModalFeature.State()

        #expect(state.score == nil)
        #expect(state.isCommentFieldVisible == false)
        #expect(state.canSubmit == false)
    }

    @Test("Picking a score reveals the comment field and enables submission")
    func scoreTappedRevealsCommentField() async {
        let store = TestStore(initialState: NPSModalFeature.State()) {
            NPSModalFeature()
        }

        await store.send(.scoreTapped(7)) {
            $0.score = 7
        }

        #expect(store.state.isCommentFieldVisible)
        #expect(store.state.canSubmit)
    }

    @Test("Picking another score replaces the previous one")
    func scoreTappedReplacesSelection() async {
        let store = TestStore(initialState: NPSModalFeature.State(score: 7)) {
            NPSModalFeature()
        }

        await store.send(.scoreTapped(2)) {
            $0.score = 2
        }
    }

    @Test("Submitting delegates the score and the comment")
    func submitTappedDelegatesAnswer() async {
        let store = TestStore(initialState: NPSModalFeature.State(score: 9)) {
            NPSModalFeature()
        }

        await store.send(\.binding.comment, "Fast and private") {
            $0.comment = "Fast and private"
        }
        await store.send(.submitTapped)
        await store.receive(.delegate(.submit(score: 9, comment: "Fast and private"))) {
            $0.didSubmit = true
        }
    }

    @Test("Submitting without a comment delegates an empty one")
    func submitTappedWithoutCommentDelegatesEmptyComment() async {
        let store = TestStore(initialState: NPSModalFeature.State(score: 0)) {
            NPSModalFeature()
        }

        await store.send(.submitTapped)
        await store.receive(.delegate(.submit(score: 0, comment: ""))) {
            $0.didSubmit = true
        }
    }

    @Test("Submitting without a score does nothing")
    func submitTappedWithoutScoreIsIgnored() async {
        let store = TestStore(initialState: NPSModalFeature.State()) {
            NPSModalFeature()
        }

        await store.send(.submitTapped)
    }

    @Test("Closing delegates a dismissal")
    func closeTappedDelegatesDismissal() async {
        let store = TestStore(initialState: NPSModalFeature.State(score: 5)) {
            NPSModalFeature()
        }

        await store.send(.closeTapped)
        await store.receive(.delegate(.dismiss))
    }
}
