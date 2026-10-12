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

/* `gmtime_r` / `timegm` are POSIX; the MSVC CRT spells them `gmtime_s` and
 * `_mkgmtime`. `ffi/rtc.lua` (the alarm/wakeup support) uses the POSIX names,
 * and raised "cannot resolve symbol 'gmtime_r'" without this.
 */

struct ko_tm {
    int tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year;
    int tm_wday, tm_yday, tm_isdst;
};

__declspec(dllimport) int _gmtime64_s(struct ko_tm *tm, const long long *time);
__declspec(dllimport) long long _mkgmtime64(struct ko_tm *tm);

KO_POSIX_EXPORT struct ko_tm *gmtime_r(const long long *time, struct ko_tm *result) {
    /* POSIX returns the result pointer, or NULL on failure. */
    return _gmtime64_s(result, time) == 0 ? result : 0;
}

KO_POSIX_EXPORT long long timegm(struct ko_tm *tm) {
    return _mkgmtime64(tm);
}

/* `clock_gettime` on top of the performance counters.
 *
 * Windows has no such function (MinGW's winpthread does not export it, and
 * neither msvcrt nor ucrtbase do), while `ffi/posix_h.lua` declares it and
 * callers use `CLOCK_MONOTONIC`-style ids. Only the monotonic clocks are
 * meaningful here: the emulation counts from process start, which is what a
 * monotonic clock is for. `CLOCK_REALTIME` is not provided (it would need the
 * wall clock, and nothing here asks for it).
 */

typedef struct {
    long long tv_sec;
    long long tv_nsec;
} ko_timespec;

__declspec(dllimport) int QueryPerformanceCounter(long long *count);
__declspec(dllimport) int QueryPerformanceFrequency(long long *freq);

#define KO_CLOCK_REALTIME  0
#define KO_CLOCK_MONOTONIC 1

KO_POSIX_EXPORT int clock_gettime(int clockid, ko_timespec *ts) {
    static long long freq, start;
    static int initialised;
    long long now;

    if (clockid == KO_CLOCK_REALTIME) {
        /* Not supported; report invalid argument rather than a wrong time. */
        return -1;
    }

    if (!initialised) {
        if (!QueryPerformanceFrequency(&freq) || freq == 0)
            return -1;
        QueryPerformanceCounter(&start);
        initialised = 1;
    }

    QueryPerformanceCounter(&now);
    /* Nanoseconds since the first call. Scaling before dividing keeps the
     * sub-second resolution that a straight `(now - start) / freq * 1e9`
     * would lose. */
    long long ns = (now - start) * 1000000000LL / freq;
    ts->tv_sec = ns / 1000000000LL;
    ts->tv_nsec = ns % 1000000000LL;
    return 0;
}
