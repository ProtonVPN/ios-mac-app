#include "include/DarwinShims.h"
#include <sys/fcntl.h>

int shim_open_dprotected(const char * _Nonnull path, int flags, shim_protection_class_t protection_class, int mode) {
    return open_dprotected_np(path, flags, protection_class, 0, mode);
}
