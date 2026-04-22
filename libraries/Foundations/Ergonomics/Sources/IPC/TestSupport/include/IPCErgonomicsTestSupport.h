#pragma once
#include "../../SeqlockHelpers/include/IPCSeqlockHelpers.h"

// ---------------------------------------------------------------------------
// Test fixtures for IPCErgonomicsTests.
// Not part of the shipped library — only linked into test targets.
// ---------------------------------------------------------------------------

typedef struct {
    double   bytes_transferred;
    uint64_t timestamp;
    uint16_t peer_migrations;
} IPCTestPayload;

IPC_DECLARE_SHARED_REGION(IPCTestRegion, IPCTestPayload);
