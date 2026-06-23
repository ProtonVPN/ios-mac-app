#pragma once
#include <stdint.h>
#include <IPCSeqlockHelpers.h>

// Mirrors CF_ENUM / NS_ENUM, tells Swift's clang importer to create a proper enum and strip the common prefix.
#if __has_attribute(enum_extensibility)
#  define IPC_ENUM(_type, _name)                                                  \
       typedef enum __attribute__((enum_extensibility(open))) _name : _type _name; \
       enum __attribute__((enum_extensibility(open))) _name : _type
#else
#  define IPC_ENUM(_type, _name) typedef enum _name : _type _name; enum _name : _type
#endif

// Tunnel data payloads coming from the extension
//
// Try to avoid using these for things that can go in the provider configuration and get read from there, it's meant for
// values that are communicated from the ProTUN framework and the LocalAgent server.

IPC_ENUM(int8_t, IPCWireGuardTransport) {
    IPCWireGuardTransportUnset = 0,
    IPCWireGuardTransportUdp   = 1,
    IPCWireGuardTransportTcp   = 2,
    IPCWireGuardTransportTls   = 3,
};

// Connection identity: who/where we are connected to, and what the server observes.
typedef struct {
    int32_t                 version;
    IPCWireGuardTransport   transport;           // The transport currently being used - can change with Smart protocol
    uint8_t                 peer_id[64];         // Raw bytes of the server id. All-zero implies no peer published yet.
    char                    server_exit_v4[46];  // IPv4 with headroom for IPv6
    char                    user_ip[46];         // The user's IP address, according to LocalAgent
    char                    user_isp[128];       // take care to properly handle UTF-8 boundary truncation (accents etc)
} IPCConnectionDataPayload;

IPC_DECLARE_SHARED_REGION(IPCConnectionDataRegion, IPCConnectionDataPayload);

// NetShield / traffic counters (mirrors LocalAgent.Stats).
typedef struct {
    int32_t                 version;
    uint64_t                bytes_received;
    uint64_t                bytes_sent;
    uint64_t                malicious_blocked;
    uint64_t                ads_blocked;
    uint64_t                trackers_blocked;
    uint64_t                adult_content_blocked;
    uint64_t                data_saved;
} IPCStatsPayload;

IPC_DECLARE_SHARED_REGION(IPCStatsRegion, IPCStatsPayload);

// Per-handshake connection metrics (mirrors LocalAgent.ConnectionStats).
typedef struct {
    int32_t                 version;
    int64_t                 timestamp_ms;
    uint64_t                received_bytes;
    uint64_t                sent_bytes;
    double                  time_since_last_handshake;
    double                  estimated_loss;
    double                  estimated_rtt;
} IPCConnectionStatsPayload;

IPC_DECLARE_SHARED_REGION(IPCConnectionStatsRegion, IPCConnectionStatsPayload);

// Most recent extension error - can be LocalAgent.Error or others.
// Just provides a domain and a code.
typedef struct {
    int32_t                 version;
    char                    domain[64];
    uint32_t                code;
} IPCErrorPayload;

IPC_DECLARE_SHARED_REGION(IPCErrorRegion, IPCErrorPayload);

// Server-applied Local Agent feature settings, mirroring what gets persisted to the provider configuration dictionary.
typedef struct {
    int32_t                 version;
    uint8_t                 netshield_level;   // NetShieldType.rawValue: 0=off, 1=malware, 2=+ads/trackers, 3=+adult
    uint8_t                 vpn_accelerator;   // bool
    uint8_t                 moderate_nat;      // bool — true => moderate NAT, false => strict
    uint8_t                 port_forwarding;   // bool
} IPCAgentFeaturesPayload;

IPC_DECLARE_SHARED_REGION(IPCAgentFeaturesRegion, IPCAgentFeaturesPayload);

// This is a single backing memory region for all of the connection data regions. Each subregion is padded to 1024 bytes
// and has its own seqlock + versioning. iOS and tvOS share this using a file-backed mmap while macOS must accomplish
// the same using an IOSurface sent over an XPC session.
typedef struct {
    IPCConnectionDataRegion   connection_data;
    IPCStatsRegion            stats;
    IPCConnectionStatsRegion  connection_stats;
    IPCErrorRegion            error;
    IPCAgentFeaturesRegion    agent_features;
} IPCTunnelData;
