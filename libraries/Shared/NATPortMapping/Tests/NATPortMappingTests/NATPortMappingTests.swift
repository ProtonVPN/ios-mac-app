import Foundation
@testable import NATPortMapping
import Testing

@Test
func portMappingRequest() async throws {
    let portMappingPacketRequest = PortMappingPacketRequest(
        portProtocol: .udp, // 1
        internalPort: 1234,
        externalPort: 5678,
        lifetime: 666
    )

    let packet = portMappingPacketRequest.serialize()

    // version: 0, opcode: 1 (udp), reservied: 0 + 0 (UInt16)
    // internal port: 1234 in binary 0000010011010010, in 2 UInt8: 00000100 11010010 = 4, 210
    // external port: 5678 in binary 0001011000101110, in 2 UInt8: 00010110 00101110 = 22, 46
    // lifetime: 666 in binary 0000001010011010, in 4 UInt8: 0 0 00000010 10011010 = 0, 0, 2, 154
    let expectedDataArray: [UInt8] = [0, 1, 0, 0, 4, 210, 22, 46, 0, 0, 2, 154]

    let expectedData = Data(expectedDataArray)
    #expect(packet == expectedData)
}

@Test
func portMappingResponse() async throws {
    // version: 0, opcode: 129 (udp), result code: 0
    // epoch time: 1752828611 in binary 01101000011110100000101011000011, in 4 UInt8: 01101000 01111010 00001010 11000011 = 104 122 10 195
    // internal port: 33333 in binary 1000001000110101, in 2 UInt8: 10000010 00110101 = 130, 53
    // external port 54321 in binary 1101010000110001, in 2 UInt8: 11010100 00110001 = 212, 49
    // lifetime: 60, in 4 UInt8: 0 0 0 00111100 = 0, 0, 0, 60
    let packetResponseDataArray: [UInt8] = [0, 129, 0, 0, 104, 122, 10, 195, 130, 53, 212, 49, 0, 0, 0, 60]

    let packetResponse = try PortMappingPacketResponse(from: Data(packetResponseDataArray))
    #expect(packetResponse.version == 0)
    #expect(packetResponse.opcode == 129)
    #expect(packetResponse.resultCode == 0)
    #expect(packetResponse.epochTime == 1_752_828_611)
    #expect(packetResponse.internalPort == 33333)
    #expect(packetResponse.mappedExternalPort == 54321)
    #expect(packetResponse.mappingLifetime == 60)
}
