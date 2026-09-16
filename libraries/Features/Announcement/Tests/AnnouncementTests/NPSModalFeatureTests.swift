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
    @Test
    func `Modal opens with nothing selected, no comment field and submission disabled`() {
        let state = NPSModalFeature.State()

        #expect(state.score == nil)
        #expect(state.isCommentFieldVisible == false)
        #expect(state.submitButtonEnabled == false)
        #expect(state.canSubmit == false)
    }

    @Test
    func `Picking a score reveals the comment field and enables submission`() async {
        let store = TestStore(initialState: NPSModalFeature.State()) {
            NPSModalFeature()
        }

        await store.send(.scoreTapped(7)) {
            $0.score = 7
        }

        #expect(store.state.isCommentFieldVisible)
        #expect(store.state.canSubmit)
        #expect(store.state.submitButtonEnabled)
    }

    @Test
    func `Picking another score replaces the previous one`() async {
        let store = TestStore(initialState: NPSModalFeature.State(score: 7)) {
            NPSModalFeature()
        }

        await store.send(.scoreTapped(2)) {
            $0.score = 2
        }
    }

    @Test
    func `Submitting sends NPS score and the comment`() async {
        let sentUseCases = LockIsolated<[NPSRequest.UseCase]>([])
        let store = TestStore(initialState: NPSModalFeature.State(score: 9)) {
            NPSModalFeature()
        } withDependencies: {
            $0.continuousClock = .immediate
            $0.announcementClient.sendNPSScore = { score, comment in
                sentUseCases.withValue { $0.append(.submit(score: score, comment: comment)) }
                return NPSResponse(code: 1000)
            }
        }

        await store.send(\.binding.comment, "Fast and private") {
            $0.comment = "Fast and private"
        }
        await store.send(.submitTapped)
        await store.receive(\.delegate.submit) {
            $0.submitInProgress = true
        }
        await store.receive(\.submitResult) {
            $0.submitInProgress = false
            $0.didSubmit = true
        }
        #expect(sentUseCases.value == [.submit(score: 9, comment: "Fast and private")])
    }

    @Test
    func `Submitting without a comment delegates an empty string`() async {
        let sentUseCases = LockIsolated<[NPSRequest.UseCase]>([])
        let store = TestStore(initialState: NPSModalFeature.State(score: 0)) {
            NPSModalFeature()
        } withDependencies: {
            $0.continuousClock = .immediate
            $0.announcementClient.sendNPSScore = { score, comment in
                sentUseCases.withValue { $0.append(.submit(score: score, comment: comment)) }
                return NPSResponse(code: 1000)
            }
        }

        await store.send(.submitTapped)
        await store.receive(\.delegate.submit) {
            $0.submitInProgress = true
        }
        await store.receive(\.submitResult) {
            $0.submitInProgress = false
            $0.didSubmit = true
        }
        #expect(sentUseCases.value == [.submit(score: 0, comment: "")])
    }

    @Test
    func `Submitting without a score does nothing`() async {
        let store = TestStore(initialState: NPSModalFeature.State()) {
            NPSModalFeature()
        }

        await store.send(.submitTapped)
    }

    @Test
    func `closing after a submission sends only the submit request`() async {
        let sentUseCases = LockIsolated<[NPSRequest.UseCase]>([])
        let store = TestStore(initialState: NPSModalFeature.State(score: 9)) {
            NPSModalFeature()
        } withDependencies: {
            $0.continuousClock = .immediate
            $0.announcementClient.sendNPSScore = { score, comment in
                sentUseCases.withValue { $0.append(.submit(score: score, comment: comment)) }
                return NPSResponse(code: 1000)
            }
        }

        await store.send(\.binding.comment, "Fast and private") {
            $0.comment = "Fast and private"
        }
        await store.send(.submitTapped)
        await store.receive(\.delegate.submit) {
            $0.submitInProgress = true
        }
        await store.receive(\.submitResult) {
            $0.submitInProgress = false
            $0.didSubmit = true
        }

        // The user closes the modal with the close button instead of the done button.
        await store.send(.closeTapped)
        await store.receive(\.delegate.dismiss) {
            $0.didDismiss = true
        }

        #expect(sentUseCases.value == [.submit(score: 9, comment: "Fast and private")])
    }

    @Test("Closing delegates a dismissal")
    func closeTappedDelegatesDismissal() async {
        let sentUseCases = LockIsolated<[NPSRequest.UseCase]>([])
        let store = TestStore(initialState: NPSModalFeature.State(score: 5)) {
            NPSModalFeature()
        } withDependencies: {
            $0.continuousClock = .immediate
            $0.announcementClient.sendNPSScore = { score, comment in
                sentUseCases.withValue { $0.append(.submit(score: score, comment: comment)) }
                return NPSResponse(code: 1000)
            }
            $0.announcementClient.sendDismissNPSScore = {
                sentUseCases.withValue { $0.append(.dismiss) }
            }
        }
        await store.send(.closeTapped)
        await store.receive(\.delegate.dismiss) {
            $0.didDismiss = true
        }
        #expect(sentUseCases.value == [.dismiss])
    }
}
