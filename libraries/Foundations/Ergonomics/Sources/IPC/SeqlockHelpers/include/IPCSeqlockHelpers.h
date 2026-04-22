#pragma once
#include <stdatomic.h>
#include <stdint.h>
#include <stdbool.h>

// ---------------------------------------------------------------------------
// IPCSharedHeader
//
// Place this as the **first member** of every shared-memory region struct.
// It carries the seqlock that RawChannel uses for lock-free consistency.
// Consumers never touch the header fields directly.
//
// Example:
//
//   typedef struct {
//       double   bytes_transferred;
//       char     server_id[64];
//       uint16_t peer_migrations;
//   } MyPayload;
//
//   IPC_DECLARE_SHARED_REGION(MyRegion, MyPayload);
//   // → MyRegion.header.seqlock is _Atomic uint64_t at offset 0
//   //   MyRegion.payload  is `MyPayload` right after the header
// ---------------------------------------------------------------------------

#if __has_attribute(swift_unavailable)
#  define IPC_SWIFT_UNAVAILABLE(msg) __attribute__((swift_unavailable(msg)))
#else
#  define IPC_SWIFT_UNAVAILABLE(msg)
#endif

typedef struct {
    _Atomic uint64_t seqlock;  // offset 0 — must only be accessed via ipc_seqlock_* primitives
} IPC_SWIFT_UNAVAILABLE("use ipc_seqlock_* primitives from Swift") IPCSharedHeader;

// Declares a complete shared-memory region struct whose first member is
// IPCSharedHeader (seqlock at offset 0) and whose second member is the user's
// payload type. The C compiler inserts any required alignment padding between
// them; RawChannel mirrors that offset on the Swift side via MemoryLayout.
#define IPC_DECLARE_SHARED_REGION(Name, PayloadType) \
    typedef struct { \
        IPCSharedHeader header;  \
        PayloadType     payload; \
    } Name

// ---------------------------------------------------------------------------
// Seqlock primitives
//
// All functions receive a `void *` pointing to the base of the region
// (i.e. the address of the IPCSharedHeader / the seqlock itself).
//
// Write protocol:  ipc_seqlock_begin_write → mutate payload → ipc_seqlock_end_write
// Read  protocol:  seq = ipc_seqlock_read_begin → copy payload → ipc_seqlock_read_end(seq)
//
// Even seqlock → no write in progress.
// Odd  seqlock → write in progress; readers spin/retry.
// ---------------------------------------------------------------------------

/// Increment seqlock to odd (write start). Call before mutating any payload field.
void ipc_seqlock_begin_write(void * _Nonnull base);

/// Increment seqlock back to even (write end). Call after all payload fields are written.
void ipc_seqlock_end_write(void * _Nonnull base);

/// Spin until no write is in progress; returns the current (even) seqlock value.
/// Pass the return value to ipc_seqlock_read_end to validate the read.
uint64_t ipc_seqlock_read_begin(const void * _Nonnull base);

/// Returns true if no write raced the read. If false, discard the snapshot and retry.
bool ipc_seqlock_read_end(const void * _Nonnull base, uint64_t expected_seq);
