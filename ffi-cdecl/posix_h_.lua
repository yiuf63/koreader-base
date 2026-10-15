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
local platform = ({{ {1} }})[platform_str]
if not platform then
    -- Windows has no entry: it is not a POSIX platform, and this module's job
    -- is to describe the POSIX interfaces a port needs. Upstream's stock
    -- configuration never reaches here (it does not build for Windows), so the
    -- declarations it would otherwise guard are simply not made -- which is
    -- what callers on Windows expect, since those symbols live in the CRT
    -- under different names (`_strdup`, `_fileno`, …).
    if ffi.os == "Windows" then
        return
    end
    error("unsupported platform: " .. platform_str)
end

-- clock_gettime & friends require librt on old glibc (< 2.17) versions...
if ffi.os == "Linux" then
    -- Load it in the global namespace to make it easier on callers...
    -- NOTE: There's no librt.so symlink, so, specify the SOVER, but not the full path,
    --       in order to let the dynamic loader figure it out on its own (e.g.,  multilib).
    pcall(ffi.load, "rt.so.1", true)
end
