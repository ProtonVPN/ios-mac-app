#pragma once
#include <stdint.h>
#include <uuid/uuid.h>
#include <IPCSeqlockHelpers.h>
#include "Macros.h"

// Tunnel data payloads coming from the extension
//
// Try to avoid using this IPC channel for things that can go in the provider configuration and get read from there,
// it's meant for values that are communicated from the ProTUN framework and the LocalAgent server. If your value is a
// configuration setting rather than a property of the active tunnel, it should go in the provider configuration.

IPC_ENUM(int8_t, IPCConnectionTransport) {
    IPCConnectionTransportUnset = 0,
    IPCConnectionTransportWireGuardUdp   = 1,
    IPCConnectionTransportWireGuardTcp   = 2,
    IPCConnectionTransportWireGuardTls   = 3,
};

// Ordinal value for `protun.ConnectionState` library
IPC_ENUM(int8_t, IPCConnectionState) {
    IPCConnectionStateDisconnected           = 0,
    IPCConnectionStateConnecting             = 1,
    IPCConnectionStateConnectingToLocalAgent = 2,
    IPCConnectionStateConnected              = 3,
};

// The packed `state`/`context` bytes below mirror the *ordinal* of one `protun` enum case per connection-state phase — we
// deliberately carry no messages or codes across the boundary, only enough to tell the cases apart. `Unset` (0) means
// "no detail", which is also exactly what a freshly-zeroed channel reads as.

// protun.DisconnectReason — meaningful when `connectionState == Disconnected`.
IPC_ENUM(int8_t, IPCConnectionDisconnectReason) {
    IPCConnectionDisconnectReasonUnset             = 0,
    IPCConnectionDisconnectReasonTunEstablishError = 1,
};

// First protun.PeerConnectionWaitReason of `connecting`'s `waitReasons` — meaningful when `connectionState == Connecting`.
IPC_ENUM(int8_t, IPCConnectionPeerWaitReason) {
    IPCConnectionPeerWaitReasonUnset             = 0,
    IPCConnectionPeerWaitReasonWaitingForNetwork = 1,
};

// protun.AgentConnectionWaitReason — meaningful when `connectionState == ConnectingToLocalAgent`.
IPC_ENUM(int8_t, IPCConnectionAgentWaitReason) {
    IPCConnectionAgentWaitReasonUnset      = 0,
    IPCConnectionAgentWaitReasonSoftJailed = 1,
    IPCConnectionAgentWaitReasonHardJailed = 2,
};

// First protun.WaitJailReason of `hardJailed`'s `jails` — paired with a HardJailed wait reason, otherwise Unset.
IPC_ENUM(int8_t, IPCConnectionAgentJailReason) {
    IPCConnectionAgentJailReasonUnset                       = 0,
    IPCConnectionAgentJailReasonBadUserBehavior             = 1,
    IPCConnectionAgentJailReasonDisabledUser                = 2,
    IPCConnectionAgentJailReasonLowPlan                     = 3,
    IPCConnectionAgentJailReasonNeed2Fa                     = 4,
    IPCConnectionAgentJailReasonPendingInvoice              = 5,
    IPCConnectionAgentJailReasonSessionOverLimit            = 6,
    IPCConnectionAgentJailReasonWaitingClientChallengeReply = 7,
    IPCConnectionAgentJailReasonInternal                    = 8,
    IPCConnectionAgentJailReasonOther                       = 9,
};

// Field sizes
#define IPV4_BYTE_LENGTH 4  // packed in_addr
#define IPV6_BYTE_LENGTH 16 // packed in6_addr
#define PEER_ID_LENGTH 64
#define ERROR_DOMAIN_LENGTH 64
#define USER_ISP_STRING_LENGTH 128

// Connection identity: who/where we are connected to, and what the server observes.
typedef struct {
    uint16_t                 version;
    // The lower nibble of `state` contains the basic connection state, while the upper nibble contains either the
    // current transport type or the reason enum value for why ProTUN is in that state.
    uint8_t                  state;
    int8_t                   context;
    uuid_t                   config_id; // The latest version of the provider configuration that's been saved
    uint8_t                  peer_id[PEER_ID_LENGTH]; // Raw bytes of the server id. Zeroes implies no peer yet.
    uint8_t                  server_exit_v4[IPV4_BYTE_LENGTH];
    uint8_t                  server_exit_v6[IPV6_BYTE_LENGTH];
    uint8_t                  user_ipv4[IPV4_BYTE_LENGTH];
    uint8_t                  user_ipv6[IPV6_BYTE_LENGTH];
    char                     user_isp[USER_ISP_STRING_LENGTH]; // Watch for UTF-8 grapheme clusters (accents).
    uint16_t                 port;
} IPCConnectionDataPayload;

IPC_DECLARE_SHARED_REGION(IPCConnectionDataRegion, IPCConnectionDataPayload);

// NetShield / traffic counters (mirrors LocalAgent.Stats).
typedef struct {
    uint16_t                version;
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
    uint16_t                version;
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
    uint16_t                version;
    uuid_t                  config_id; // The provider configuration this error was associated with, if any
    char                    domain[ERROR_DOMAIN_LENGTH];
    uint32_t                code;
} IPCErrorPayload;

IPC_DECLARE_SHARED_REGION(IPCErrorRegion, IPCErrorPayload);

// Server-applied Local Agent feature settings, mirroring what gets persisted to the provider configuration dictionary.
typedef struct {
    uint16_t                version;
    uint8_t                 netshield_level;   // NetShieldType.rawValue: 0=off, 1=malware, 2=+ads/trackers, 3=+adult
    uint8_t                 vpn_accelerator;   // bool
    uint8_t                 moderate_nat;      // bool — true => moderate NAT, false => strict
    uint8_t                 port_forwarding;   // bool
} IPCAgentFeaturesPayload;

IPC_DECLARE_SHARED_REGION(IPCAgentFeaturesRegion, IPCAgentFeaturesPayload);

// This is a single backing memory region for all of the connection data regions. Each subregion is padded to 1024 bytes
// and has its own seqlock + versioning. iOS and tvOS share this using a file-backed mmap while macOS must accomplish
// the same using an IOSurface sent over an XPC session.
//
// Append-only: new regions go at the end so existing field offsets stay stable across app/extension builds.
typedef struct {
    IPCConnectionDataRegion     connection_data;
    IPCStatsRegion              stats;
    IPCConnectionStatsRegion    connection_stats;
    IPCErrorRegion              error;
    IPCAgentFeaturesRegion      agent_features;
} IPCTunnelData;
