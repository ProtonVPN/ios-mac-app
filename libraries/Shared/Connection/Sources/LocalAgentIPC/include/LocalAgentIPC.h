#pragma once
#include <stdint.h>
#include <IPCSeqlockHelpers.h>

// ---------------------------------------------------------------------------
// IPC_ENUM
//
// Mirrors CF_ENUM / NS_ENUM: the forward-declaration trick + enum_extensibility
// tells Swift's Clang importer to:
//   • import the type as a proper Swift enum (not a raw struct wrapper)
//   • strip the common prefix from case names so dot syntax works
//     e.g. LocalAgentNetshieldMalware → LocalAgentNetshieldLevel.malware
// ---------------------------------------------------------------------------
#if __has_attribute(enum_extensibility)
#  define IPC_ENUM(_type, _name)                                                  \
       typedef enum __attribute__((enum_extensibility(open))) _name : _type _name; \
       enum __attribute__((enum_extensibility(open))) _name : _type
#else
#  define IPC_ENUM(_type, _name) typedef enum _name : _type _name; enum _name : _type
#endif

// ---------------------------------------------------------------------------
// Live connection telemetry — extension-written, app reads/observes
//
// The network extension is the SOLE writer of all four regions below; the app
// only reads/observes. They carry everything that is *not* a tunnel setting
// (tunnel settings live on ProTUNConfiguration in the providerConfiguration
// dictionary, not here).
//
// They are deliberately split into four independent regions — connection
// identity, traffic stats, handshake stats, and the last error — each with its
// own backing file, notification, and `version`. The split keeps every ABI small
// and independently versionable, and stops the high-frequency stats writes from
// contending on the same seqlock as the latency-sensitive peer/error fields.
//
// `version` lets a reader detect a payload written by an incompatible build.
// String fields are fixed-size char[] (so each struct stays BitwiseCopyable);
// they are NUL-terminated UTF-8, truncated on codepoint boundaries by the Swift
// marshaling helpers. The connection timestamp is NOT carried — the app uses
// NEVPNConnection.connectedDate.
// ---------------------------------------------------------------------------

IPC_ENUM(int8_t, IPCWireGuardTransport) {
    IPCWireGuardTransportUnset = 0,
    IPCWireGuardTransportUdp   = 1,
    IPCWireGuardTransportTcp   = 2,
    IPCWireGuardTransportTls   = 3,
};

// Connection identity: who/where we are connected to, and what the server observes.
typedef struct {
    int32_t                 version;
    IPCWireGuardTransport   transport;
    uint8_t                 peer_id[64];         // Raw bytes of the server id (PVPNServerIpID). It is an 88-char base64url string elsewhere; we carry it DECODED (exactly 64 bytes) so it fits without bloating the ABI. The marshaling layer base64url-encodes it back to the string the app keys its server lookup on. All-zero == no peer published yet.
    char                    server_exit_v4[46];  // IPv4 (max 15) with headroom for IPv6 textual forms
    char                    user_isp[128];       // take care to properly handle UTF-8 boundary truncation
    char                    user_ip[46];
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
    double                  estimated_loss;              // Float on the Swift side
    double                  estimated_rtt;
} IPCConnectionStatsPayload;

IPC_DECLARE_SHARED_REGION(IPCConnectionStatsRegion, IPCConnectionStatsPayload);

// Most recent extension error (mirrors LocalAgent.Error); single slot, latest wins.
typedef struct {
    int32_t                 version;
    char                    domain[64];
    uint32_t                code;
} IPCErrorPayload;

IPC_DECLARE_SHARED_REGION(IPCErrorRegion, IPCErrorPayload);
