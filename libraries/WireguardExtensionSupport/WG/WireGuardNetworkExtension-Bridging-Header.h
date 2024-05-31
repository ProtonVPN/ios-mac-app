#ifndef _WireGuard_Bridging_Header_h_
#define _WireGuard_Bridging_Header_h_

#include "../WireGuardKitC/WireGuardKitC.h"
#include "../WireGuardKitGo/wireguard.h"
#include "ringlogger.h"

#include <TargetConditionals.h>
#if !TARGET_OS_IPHONE && TARGET_OS_OSX
#include "../../../apps/macos/ExtensionsIPC/AuditTokenGetter.h"
#endif

#endif
