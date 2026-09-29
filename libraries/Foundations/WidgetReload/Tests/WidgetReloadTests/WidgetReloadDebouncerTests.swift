//
//  Created on 29/09/2026 by Pawel Jurczyk.
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

import Clocks
import ConcurrencyExtras
import Dependencies
import Testing
@testable import WidgetReload

@Suite("Widget reload debouncer")
struct WidgetReloadDebouncerTests {
    /// The debounce window `Debouncer` waits out before reloading.
    private static let debounceWindow = Duration.seconds(0.5)

    /// Records what the debouncer asked `WidgetKit` to do.
    private final class Recorder: Sendable {
        let reloads = LockIsolated(0)
        let largeWidgetQueries = LockIsolated(0)
    }

    private func withDebouncer(
        hasLargeWidgetInstalled: Bool = true,
        _ body: (WidgetReload.Debouncer, TestClock<Duration>, Recorder) async throws -> Void
    ) async rethrows {
        let clock = TestClock()
        let recorder = Recorder()
        let debouncer = withDependencies {
            $0.continuousClock = clock
            $0.widgetCenter = WidgetCenterClient(
                hasLargeWidgetInstalled: {
                    recorder.largeWidgetQueries.withValue { $0 += 1 }
                    return hasLargeWidgetInstalled
                },
                reloadAllTimelines: { recorder.reloads.withValue { $0 += 1 } }
            )
        } operation: {
            WidgetReload.Debouncer()
        }
        try await body(debouncer, clock, recorder)
    }

    // MARK: - Debouncing

    @Test("Collapses a burst of requests into a single reload")
    func collapsesABurstIntoOneReload() async {
        await withMainSerialExecutor {
            await withDebouncer { debouncer, clock, recorder in
                await debouncer.reload(.defaultConnectionChanged)
                await debouncer.reload(.loggedInOrOut)
                await debouncer.reload(.defaultConnectionChanged)

                await clock.advance(by: Self.debounceWindow)

                #expect(recorder.reloads.value == 1)
            }
        }
    }

    @Test("Holds the reload until the debounce window has elapsed")
    func waitsOutTheDebounceWindow() async {
        await withMainSerialExecutor {
            await withDebouncer { debouncer, clock, recorder in
                await debouncer.reload(.loggedInOrOut)

                await clock.advance(by: .seconds(0.4))
                #expect(recorder.reloads.value == 0)

                await clock.advance(by: .seconds(0.1))
                #expect(recorder.reloads.value == 1)
            }
        }
    }

    // MARK: - Connection state de-duplication

    @Test("Ignores a connection state that was already reloaded for")
    func ignoresARepeatedConnectionState() async {
        await withMainSerialExecutor {
            await withDebouncer { debouncer, clock, recorder in
                await debouncer.reload(.connectionStateChanged(.connected))
                await clock.advance(by: Self.debounceWindow)
                #expect(recorder.reloads.value == 1)

                await debouncer.reload(.connectionStateChanged(.connected))
                await clock.advance(by: Self.debounceWindow)

                #expect(recorder.reloads.value == 1)
            }
        }
    }

    @Test("Reloads again when the connection state actually changes")
    func reloadsOnADifferentConnectionState() async {
        await withMainSerialExecutor {
            await withDebouncer { debouncer, clock, recorder in
                await debouncer.reload(.connectionStateChanged(.connecting))
                await clock.advance(by: Self.debounceWindow)

                await debouncer.reload(.connectionStateChanged(.connected))
                await clock.advance(by: Self.debounceWindow)

                #expect(recorder.reloads.value == 2)
            }
        }
    }

    // MARK: - Recents

    @Test("Skips a recents change when no large widget is installed")
    func skipsRecentsWithoutALargeWidget() async {
        await withMainSerialExecutor {
            await withDebouncer(hasLargeWidgetInstalled: false) { debouncer, clock, recorder in
                await debouncer.reload(.recentsListChanged)

                await clock.advance(by: Self.debounceWindow)

                #expect(recorder.reloads.value == 0)
                #expect(recorder.largeWidgetQueries.value == 1)
            }
        }
    }

    @Test("Reloads a recents change when a large widget is installed")
    func reloadsRecentsWithALargeWidget() async {
        await withMainSerialExecutor {
            await withDebouncer(hasLargeWidgetInstalled: true) { debouncer, clock, recorder in
                await debouncer.reload(.recentsListChanged)

                await clock.advance(by: Self.debounceWindow)

                #expect(recorder.reloads.value == 1)
            }
        }
    }

    @Test("Only the recents reason needs to know which widgets are installed")
    func doesNotQueryInstalledWidgetsForOtherReasons() async {
        await withMainSerialExecutor {
            await withDebouncer { debouncer, clock, recorder in
                await debouncer.reload(.loggedInOrOut)
                await debouncer.reload(.defaultConnectionChanged)
                await debouncer.reload(.connectionStateChanged(.disconnected))

                await clock.advance(by: Self.debounceWindow)

                #expect(recorder.largeWidgetQueries.value == 0)
                #expect(recorder.reloads.value == 1)
            }
        }
    }
}
