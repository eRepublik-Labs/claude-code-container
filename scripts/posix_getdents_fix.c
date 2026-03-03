// ABOUTME: LD_PRELOAD shim providing posix_getdents for musl libc compatibility
// ABOUTME: Workaround for Claude Code v2.1.63+ requiring glibc-specific symbol (anthropics/claude-code#29559)

#define _GNU_SOURCE
#include <sys/syscall.h>
#include <unistd.h>

ssize_t posix_getdents(int fd, void *buf, size_t count) {
    return syscall(SYS_getdents64, fd, buf, count);
}
