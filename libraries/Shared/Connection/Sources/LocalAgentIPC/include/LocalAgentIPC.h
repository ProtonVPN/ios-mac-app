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
// LocalAgent IPC payload types
//
// Shared effective LA settings snapshot. Both the app and the extension read
// and write it. Field set intentionally differs from both `LocalAgent.SettingType`
// (which mirrors the Rust FFI policy-refusal enum) and from
// `ConnectionFeatureChange.AgentFeature` (the user-writable subset). For example
// `circumvention_routing` has no user toggle, and `bouncing` is not LA-persisted
// on iOS so doesn't appear here.
//
// All enums use 0 as the "not yet set" sentinel so a freshly mmap-initialised
// region (all zeros) is unambiguously interpreted as "no data written yet".
// ---------------------------------------------------------------------------

IPC_ENUM(int8_t, IPCLANetshieldLevel) {
    IPCLANetshieldLevelUnset                        = 0,
    IPCLANetshieldLevelOff                          = 1,
    IPCLANetshieldLevelMalware                      = 2,
    IPCLANetshieldLevelAdsAndMalware                = 3,
    IPCLANetshieldLevelAdultContentAndAdsAndMalware = 4,
};

IPC_ENUM(int8_t, IPCLASettingsToggle) {
    IPCLASettingsToggleUnset    = 0,
    IPCLASettingsToggleDisabled = 1,
    IPCLASettingsToggleEnabled  = 2,
};

IPC_ENUM(int8_t, IPCLANATType) {
    IPCLANATTypeUnset    = 0,
    IPCLANATTypeModerate = 1,
    IPCLANATTypeStrict   = 2,
};

// Mirrors LocalAgentSettings from the Rust FFI.
typedef struct {
    IPCLANetshieldLevel     netshield_level;
    IPCLASettingsToggle     vpn_accelerator;     // splitTcp
    IPCLASettingsToggle     port_forwarding;
    IPCLANATType            random_nat;
    IPCLASettingsToggle     soft_jail;
    IPCLASettingsToggle     circumvention_routing;
} IPCLASettingsPayload;

IPC_DECLARE_SHARED_REGION(IPCLASettingsRegion, IPCLASettingsPayload);
