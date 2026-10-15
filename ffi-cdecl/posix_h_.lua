-- Automatically generated with {0}.

local ffi = require("ffi")

local platform_str
if os.getenv("IS_ANDROID") then
    platform_str = "android_" .. ffi.arch
elseif ffi.os == "OSX" then
    platform_str = "macos"
elseif ffi.os == "Linux" then
    platform_str = ffi.os:lower() .. "_" .. ffi.libc:lower() .. "_" .. ffi.arch
else
    platform_str = ffi.os:lower() .. "_" .. ffi.arch
end
local platforms = {{ {1} }}
local platform = platforms[platform_str]
if not platform then
    -- Windows has no entry in the table: upstream does not build for it, and
    -- every entry describes a platform whose C library differs from the
    -- Microsoft CRT.
    --
    -- It cannot simply be skipped, though. The declarations below are a mix:
    -- some are gated on the platform, some are not, and the ungated ones are
    -- general C library calls the frontend uses everywhere -- `blitbuffer.lua`
    -- allocates with `C.calloc` (via `ffi/posix`), to name one. Worse, the
    -- ungated ones are written in terms of types the *gated* ones introduce
    -- (`pthread_attr_t`, `time_t`, ...), so leaving `platform` unset makes them
    -- fail to parse:
    --
    --     ffi/posix_h.lua:1082: declaration specifier expected near 'pthread_attr_t'
    --
    -- Borrowing an existing entry resolves both: the types are all defined, the
    -- ungated blocks parse, and the gated blocks additionally declare some POSIX
    -- functions the CRT does not have. That last part is harmless -- LuaJIT
    -- resolves a symbol when it is called, not when it is declared, and the
    -- Windows code paths do not call them (`ui/time.lua` uses
    -- `QueryPerformanceCounter`, and `ffi/SDL3.lua` provides its own
    -- `clock_gettime`).
    --
    -- `linux_gnu_x64` is picked for word size, which is what the struct layouts
    -- below turn on.
    if ffi.os == "Windows" then
        platform = platforms.linux_gnu_x64
    else
        error("unsupported platform: " .. platform_str)
    end
end

-- clock_gettime & friends require librt on old glibc (< 2.17) versions...
if ffi.os == "Linux" then
    -- Load it in the global namespace to make it easier on callers...
    -- NOTE: There's no librt.so symlink, so, specify the SOVER, but not the full path,
    --       in order to let the dynamic loader figure it out on its own (e.g.,  multilib).
    pcall(ffi.load, "rt.so.1", true)
end

-- The Microsoft CRT spells a few calls differently, and the frontend reaches for
-- those spellings directly: `ffi/util.lua` uses `_fileno` and `_commit` to flush
-- a file descriptor, `ffi/koptcontext.lua` uses `_strdup`. The declarations below
-- are the POSIX ones, and the CRT does not export them; MinGW builds against
-- msvcrt, which has only the underscore-prefixed names.
--
-- `FILE` is declared here even though the generated blocks define it further
-- down: this prolog runs first, and `_fileno` needs the type to parse at all.
-- The two declarations say the same thing, and `ffi.cdef` accepts a repeated
-- identical typedef.
--
-- NOTE: braces are built at runtime -- `str.format` runs over this file, so a
--       literal pair would be read as a replacement field.
if ffi.os == "Windows" then
    local open, close = string.char(123), string.char(125)
    local nl = string.char(10)
    ffi.cdef(
        "typedef struct _IO_FILE FILE;" .. nl
        .. "char *_strdup(const char *);" .. nl
        .. "char *_strndup(const char *, size_t);" .. nl
        .. "int _fileno(FILE *);" .. nl
        .. "int _commit(int);"
    )
end
