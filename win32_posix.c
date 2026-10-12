/* POSIX names for the MSVC CRT, for the Windows build.
 *
 * MSVCRT exports the underscore-prefixed spellings only (`_open`, not `open`),
 * while KOReader's Lua code calls the POSIX ones (`C.open` and friends, ~86 call
 * sites). `ffi.C` resolves a symbol against the process image and **its import
 * table** — that is how `C.strerror` and `C.malloc` already work — so exporting
 * these wrappers from `koreader.exe` itself makes every one of those call sites
 * resolve, with no Lua changes and no per-call shim in the frontend.
 *
 * NOTE: the return types are deliberately 32-bit, matching what the CRT itself
 *       returns, even though `ffi/posix_h.lua` declares `ssize_t` (64-bit):
 *       LuaJIT converts a 64-bit integer result to a **cdata** rather than a Lua
 *       number, and callers do arithmetic and `string.format` on these values
 *       (`gettext.lua` compares `read()`'s result against a length, for one).
 *       A 32-bit return keeps them plain numbers, and no file KOReader reads is
 *       anywhere near 2 GiB.
 *       `lseek` likewise takes/returns `off_t`, which the FFI types as a 32-bit
 *       `long` on Windows.
 *
 *       No CRT header is included: `<fcntl.h>` pulls in `<io.h>`, which declares
 *       these very names with the MSVC prototypes, and would conflict.
 */

#include <stdarg.h>
#include <stddef.h>

/* From <fcntl.h> (MSVC spellings; the values are part of the CRT ABI). */
#define KO_O_CREAT  0x0100
#define KO_O_BINARY 0x8000

__declspec(dllimport) int _open(const char *path, int flags, ...);
__declspec(dllimport) int _close(int fd);
__declspec(dllimport) int _read(int fd, void *buf, unsigned int count);
__declspec(dllimport) int _write(int fd, const void *buf, unsigned int count);
__declspec(dllimport) long _lseek(int fd, long offset, int whence);

#define KO_POSIX_EXPORT __declspec(dllexport)

KO_POSIX_EXPORT int open(const char *path, int flags, ...) {
    int mode = 0;
    if (flags & KO_O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, int);
        va_end(ap);
    }
    /* The CRT opens in *text* mode by default, which quietly rewrites CRLF to LF
     * on the way in and shortens the read. POSIX has no such mode, so callers
     * reasonably expect the bytes they asked for: a `.mo` translation catalogue
     * is binary, and `gettext` failed to load it with a short read until this
     * was forced. (`O_BINARY` is also accepted from callers that pass it.) */
    return _open(path, flags | KO_O_BINARY, mode);
}

KO_POSIX_EXPORT int close(int fd) {
    return _close(fd);
}

/* `size_t` is 64-bit, but `_read`/`_write` take an `unsigned int`, so transfer
 * at most what fits rather than truncating the request. */
#define KO_CHUNK(n) ((n) > 0x7fffffffu ? 0x7fffffffu : (unsigned int)(n))

KO_POSIX_EXPORT int read(int fd, void *buf, size_t count) {
    return _read(fd, buf, KO_CHUNK(count));
}

KO_POSIX_EXPORT int write(int fd, const void *buf, size_t count) {
    return _write(fd, buf, KO_CHUNK(count));
}

KO_POSIX_EXPORT long lseek(int fd, long offset, int whence) {
    return _lseek(fd, offset, whence);
}
