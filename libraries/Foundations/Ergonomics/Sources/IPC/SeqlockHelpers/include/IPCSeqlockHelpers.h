#pragma once
#include <stdatomic.h>
#include <stdint.h>
#include <stdbool.h>

#if __has_attribute(swift_unavailable)
#  define IPC_SWIFT_UNAVAILABLE(msg) __attribute__((swift_unavailable(msg)))
#else
#  define IPC_SWIFT_UNAVAILABLE(msg)
#endif

// ---------------------------------------------------------------------------
// IPCSharedHeader
//
// The header item of every shared region is an atomically incrementing counter that is used to signal read/write
// consistency of its associated region. It is accessed/incremented using the `ipc_seqlock_*` functions further down.
//
// Only use the `IPC_DECLARE_SHARED_REGION` macro to place this item at the start of your shared memory region.
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
//   // - MyRegion.header.seqlock is _Atomic uint64_t at offset 0
//   // - MyRegion.payload  is `MyPayload` right after the header
// ---------------------------------------------------------------------------

typedef struct {
    _Atomic uint64_t seqlock;  // offset 0 — must only be accessed via ipc_seqlock_* primitives
} IPC_SWIFT_UNAVAILABLE("use ipc_seqlock_* primitives from Swift") IPCSharedHeader;

// The fixed size of every shared region. If the payload is less than this size, the rest of the region is padded to
// compensate. This is to better guarantee binary compatibility between the extension and the main application should
// the two ever mismatch, as can be the case on macOS.
//
// There's also no technical reason why the regions can't be different sizes, but if you plan on needing a bigger region
// make sure to append it to the end, and make sure that further regions stay 128-byte aligned, for caching reasons.
#define IPC_SHARED_REGION_SIZE 1024

// Declares a shared memory region, complete with the seqlock header, the payload itself, and the padding at the end to
// reach `IPC_SHARED_REGION_SIZE` bytes for the total region size. Also throws in a _Static_assert for good measure.
#define IPC_DECLARE_SHARED_REGION(Name, PayloadType) \
    typedef struct { \
        IPCSharedHeader header;  \
        PayloadType     payload; \
        char            _reserved[IPC_SHARED_REGION_SIZE - sizeof(IPCSharedHeader) - sizeof(PayloadType)]; \
    } Name; \
    _Static_assert(sizeof(Name) == IPC_SHARED_REGION_SIZE, #Name " must be exactly IPC_SHARED_REGION_SIZE bytes")

// ---------------------------------------------------------------------------
// Seqlock primitives
//
// All functions receive a `void *` pointing to the base of the region
// (i.e. the address of the IPCSharedHeader / the seqlock itself).
//
// Write protocol: ipc_seqlock_begin_write, mutate payload, ipc_seqlock_end_write.
// Read protocol: seq = ipc_seqlock_read_begin, copy payload, ipc_seqlock_read_end(seq) + check return value.
//
// An even seqlock implies no write in progress.
// An odd seqlock implies that a write is in progress and readers should spin/retry.
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
