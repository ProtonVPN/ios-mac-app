#pragma once

// C shims for Darwin functions Swift cannot call directly.

/// The data protection class a file is created in. xnu declares these in bsd/sys/fcntl.h behind PRIVATE, so the
/// public SDK does not export them and the values are restated here, from
/// https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/fcntl.h. The kernel defines further classes we
/// never ask for, so this is not the whole table.
typedef enum __attribute__((enum_extensibility(closed)))
__attribute__((swift_name("DataProtectionClass")))
shim_protection_class : int {
    SHIM_PROTECTION_CLASS_A __attribute__((swift_name("classA"))) = 1,
    SHIM_PROTECTION_CLASS_B __attribute__((swift_name("classB"))) = 2,
    SHIM_PROTECTION_CLASS_C __attribute__((swift_name("classC"))) = 3,
    SHIM_PROTECTION_CLASS_D __attribute__((swift_name("classD"))) = 4,
} shim_protection_class_t;

/// Calls open_dprotected_np, which Swift cannot reach because it is variadic. Returns a descriptor or -1, like open(2).
int shim_open_dprotected(const char * _Nonnull path, int flags, shim_protection_class_t protection_class, int mode);
