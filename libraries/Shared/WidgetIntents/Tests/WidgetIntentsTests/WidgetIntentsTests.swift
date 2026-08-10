import AppIntents
import Testing
@testable import WidgetIntents

// Ensures existing shortcut identifiers don't change, which can break compatibility with previous app versions.
@Test
func shippedActionIdentifiersAreStable() {
    #expect(ConnectToVPNIntent.persistentIdentifier == "ConnectToVPNIntent")
    #expect(ConnectToRegionIntent.persistentIdentifier == "ConnectToRegionIntent")
    #expect(DisconnectVPNIntent.persistentIdentifier == "DisconnectVPNIntent")
    #expect(GetConnectionStatusIntent.persistentIdentifier == "GetConnectionStatusIntent")
    #expect(ShowConnectionStatus.persistentIdentifier == "ShowConnectionStatus")
}
