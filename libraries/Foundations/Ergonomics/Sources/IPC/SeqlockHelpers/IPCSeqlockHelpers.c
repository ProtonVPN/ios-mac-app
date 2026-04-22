#include "include/IPCSeqlockHelpers.h"
#include <stdatomic.h>

void ipc_seqlock_begin_write(void * _Nonnull base) {
    _Atomic uint64_t *seqlock = (_Atomic uint64_t *)base;
    atomic_fetch_add_explicit(seqlock, 1, memory_order_relaxed);
    atomic_thread_fence(memory_order_release);
}

void ipc_seqlock_end_write(void * _Nonnull base) {
    _Atomic uint64_t *seqlock = (_Atomic uint64_t *)base;
    atomic_thread_fence(memory_order_release);
    atomic_fetch_add_explicit(seqlock, 1, memory_order_relaxed);
}

uint64_t ipc_seqlock_read_begin(const void * _Nonnull base) {
    const _Atomic uint64_t *seqlock = (const _Atomic uint64_t *)base;
    uint64_t seq;
    do {
        seq = atomic_load_explicit(seqlock, memory_order_acquire);
    } while (seq & 1);
    return seq;
}

bool ipc_seqlock_read_end(const void * _Nonnull base, uint64_t expected_seq) {
    const _Atomic uint64_t *seqlock = (const _Atomic uint64_t *)base;
    atomic_thread_fence(memory_order_acquire);
    return atomic_load_explicit(seqlock, memory_order_relaxed) == expected_seq;
}
