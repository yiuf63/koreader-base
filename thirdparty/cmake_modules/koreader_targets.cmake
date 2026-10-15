include_guard(GLOBAL)

include(koreader_thirdparty_common)
include(koreader_thirdparty_libs)

function(declare_koreader_target NAME)
    cmake_parse_arguments("" "EXCLUDE_FROM_ALL" "SUFFIX;TYPE;VISIBILITY" "DEPENDS;SOURCES" ${ARGN})
    set(${NAME}_TYPE ${_TYPE} PARENT_SCOPE)
    set(${NAME}_DEPENDS ${_DEPENDS} PARENT_SCOPE)
    set(${NAME}_EXCLUDE_FROM_ALL ${_EXCLUDE_FROM_ALL} PARENT_SCOPE)
    set(${NAME}_SUFFIX ${_SUFFIX} PARENT_SCOPE)
    set(${NAME}_SOURCES ${_SOURCES} PARENT_SCOPE)
    set(${NAME}_VISIBILITY ${_VISIBILITY} PARENT_SCOPE)
    set(KOREADER_TARGETS ${KOREADER_TARGETS} ${NAME} PARENT_SCOPE)
endfunction()

function(setup_target NAME)
    if(${NAME}_TYPE STREQUAL "executable")
        add_executable(${NAME})
        set(_DESTINATION ${OUTPUT_DIR})
    elseif(${NAME}_TYPE STREQUAL "library")
        add_library(${NAME} SHARED)
        set(_DESTINATION ${OUTPUT_DIR}/libs)
    elseif(${NAME}_TYPE STREQUAL "monolibtic")
        if(MONOLIBTIC)
            add_library(${NAME} OBJECT)
        else()
            add_library(${NAME} SHARED)
        endif()
        set(_DESTINATION ${OUTPUT_DIR}/libs)
    else()
        message(FATAL_ERROR "unsupported target '${NAME}' type: ${${NAME}_TYPE}")
    endif()
    if(${NAME}_TYPE STREQUAL "monolibtic" AND MONOLIBTIC)
        set(OBJLIB TRUE)
    else()
        set(OBJLIB FALSE)
    endif()
    if(${NAME}_DEPENDS)
        target_link_libraries(${NAME} PRIVATE ${${NAME}_DEPENDS})
    endif()
    if(${NAME}_SUFFIX AND NOT OBJLIB)
        set_target_properties(${NAME} PROPERTIES SUFFIX ${${NAME}_SUFFIX})
    endif()
    if(${NAME}_VISIBILITY)
        if(${NAME}_VISIBILITY STREQUAL "hidden")
            set_target_properties(${NAME} PROPERTIES VISIBILITY_INLINES_HIDDEN TRUE)
        endif()
        set_target_properties(${NAME} PROPERTIES
            C_VISIBILITY_PRESET ${${NAME}_VISIBILITY}
            CXX_VISIBILITY_PRESET ${${NAME}_VISIBILITY}
        )
    endif()
    target_compile_options(${NAME} PRIVATE -Wall)
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        target_compile_definitions(${NAME} PRIVATE DEBUG)
    endif()
    set_target_properties(${NAME} PROPERTIES EXCLUDE_FROM_ALL ${${NAME}_EXCLUDE_FROM_ALL})
    target_sources(${NAME} PRIVATE ${${NAME}_SOURCES})
    # Post-build install command.
    if(NOT OBJLIB)
        set(INSTALL_CMD)
        append_binary_install_command(INSTALL_CMD $<TARGET_FILE_NAME:${NAME}> DESTINATION ${_DESTINATION})
        add_custom_command(TARGET ${NAME} POST_BUILD VERBATIM ${INSTALL_CMD})
    endif()
    # Custom finalization.
    string(REPLACE "-" "_" SETUP setup_${NAME})
    if(COMMAND ${SETUP})
        # Work around lack of `cmake_language(CALL …)` until version 3.18.
        set(FNAME ${CMAKE_CURRENT_BINARY_DIR}/${SETUP}.cmake)
        file(WRITE ${FNAME} "${SETUP}()\n")
        include(${FNAME})
    endif()
endfunction()

# KOREADER LIBRARIES. {{{

# blitbuffer
if(ANDROID OR BOOKEEN OR CERVANTES OR KINDLE OR KOBO OR POCKETBOOK OR REMARKABLE OR USE_SDL)
    set(EXCLUDE_FROM_ALL)
else()
    set(EXCLUDE_FROM_ALL EXCLUDE_FROM_ALL)
endif()
declare_koreader_target(
    blitbuffer TYPE monolibtic
    ${EXCLUDE_FROM_ALL}
    SOURCES blitbuffer.c
    VISIBILITY hidden
)
function(setup_blitbuffer)
    target_compile_options(blitbuffer PRIVATE -Wno-maybe-uninitialized SHELL:${VECTO_CFLAGS})
endfunction()

# `SUFFIX ${CMAKE_SHARED_MODULE_SUFFIX}` for the `monolibtic` targets below.
#
# They are loaded with `require("libs/libkoreader-…")`, so Lua resolves them
# through `package.cpath`, which lists `?.dll` and `?.so` and nothing else.
# `LIB_EXT` would be wrong on macOS: it is the `SHARED` suffix (`.dylib`
# there), while `CMAKE_SHARED_MODULE_SUFFIX` defaults to it and is overridden
# to `.so` by `Darwin.cmake` for precisely this reason. So the module suffix
# is `.dll` on Windows, `.so` on macOS and Linux -- the two `cpath` entries.
#
# This was a hardcoded `.so` upstream, which was correct on macOS and Linux
# and wrong on Windows.

# koreade-cre
declare_koreader_target(
    koreader-cre TYPE monolibtic
    DEPENDS crengine::crengine luajit::luajit
    SOURCES cre.cpp
    SUFFIX ${CMAKE_SHARED_MODULE_SUFFIX}
    VISIBILITY hidden
)

# koreader-djvu
declare_koreader_target(
    koreader-djvu TYPE monolibtic
    DEPENDS blitbuffer djvulibre::djvulibre libk2pdfopt::k2pdfopt luajit::luajit
    SOURCES djvu.c
    SUFFIX ${CMAKE_SHARED_MODULE_SUFFIX}
    VISIBILITY hidden
)
function(setup_koreader_djvu)
    if(WIN32)
        # NOTE: djvulibre is built as a static library (see its spec), but its
        #       headers default to `__declspec(dllimport)` on Windows, which
        #       makes every `ddjvu_*` / `miniexp_*` reference unresolvable.
        #       Defining the macros empty is the documented way to consume the
        #       static build.
        target_compile_definitions(koreader-djvu PRIVATE DDJVUAPI= MINILISPAPI=)
    endif()
endfunction()

# kodeader-input
set(DEPENDS luajit::luajit)
if(KINDLE OR REMARKABLE)
    list(APPEND DEPENDS popen-noshell::popen-noshell)
endif()
if(ANDROID OR POCKETBOOK OR USE_SDL)
    set(EXCLUDE_FROM_ALL EXCLUDE_FROM_ALL)
else()
    set(EXCLUDE_FROM_ALL)
endif()
declare_koreader_target(
    koreader-input TYPE monolibtic
    DEPENDS ${DEPENDS}
    ${EXCLUDE_FROM_ALL}
    SOURCES input/input.c
    VISIBILITY hidden
)
function(setup_koreader_input)
    foreach(PLATFORM BOOKEEN CERVANTES KOBO KINDLE LEGACY REMARKABLE)
        if(${PLATFORM})
            if(PLATFORM STREQUAL "LEGACY")
                set(PLATFORM KINDLE_LEGACY)
            endif()
            target_compile_definitions(koreader-input PRIVATE -D${PLATFORM})
        endif()
    endforeach()
endfunction()

# koreader-nnsvg
declare_koreader_target(
    koreader-nnsvg TYPE monolibtic
    DEPENDS luajit::luajit nanosvg::nanosvg
    SOURCES nnsvg.c
    SUFFIX ${CMAKE_SHARED_MODULE_SUFFIX}
    VISIBILITY hidden
)

# koreader-xtext
declare_koreader_target(
    koreader-xtext TYPE monolibtic
    DEPENDS freetype2::freetype fribidi::fribidi harfbuzz::harfbuzz luajit::luajit libunibreak::unibreak
    SOURCES xtext.cpp
    SUFFIX ${CMAKE_SHARED_MODULE_SUFFIX}
    VISIBILITY hidden
)

# wrap-mupdf
declare_koreader_target(
    wrap-mupdf TYPE monolibtic
    DEPENDS mupdf::mupdf
    SOURCES wrap-mupdf.c
    VISIBILITY hidden
)
function(setup_wrap_mupdf)
    if(NOT MONOLIBTIC)
        target_exports(wrap-mupdf CDECLS wrap-mupdf_cdecl)
    endif()
endfunction()

# }}}

# MISCELLANY. {{{

# extr
declare_koreader_target(
    extr TYPE executable
    DEPENDS mupdf::mupdf
    EXCLUDE_FROM_ALL
    SOURCES extr.c
)

# koreader
# NOTE: `osx_loader` uses Mach-O specific APIs, so it is macOS-only; Windows has
#       its own entry point (`win_loader_exe` below). Both are named `koreader`
#       when built, hence the mutually exclusive conditions (CMake's build graph
#       cannot have two targets producing the same file).
if(APPLE)
    declare_koreader_target(
        osx_loader TYPE executable
        DEPENDS luajit::luajit
        SOURCES osx_loader.c
    )
    function(setup_osx_loader)
        set_target_properties(osx_loader PROPERTIES OUTPUT_NAME koreader)
    endfunction()
endif()

# win_loader
if(WIN32)
    declare_koreader_target(
        win_loader_exe TYPE executable
        DEPENDS luajit::luajit
        # The `.rc` only carries the application manifest, which opts the process
        # into UTF-8 as its active code page (see win_loader.manifest).
        # `win32_posix.c` exports the POSIX spellings of the CRT file calls for
        # `ffi.C` to find (see the file's own comment).
        SOURCES win_loader.c win32_posix.c win_loader.rc
    )
    function(setup_win_loader_exe)
        set_target_properties(win_loader_exe PROPERTIES OUTPUT_NAME koreader)
        # Keep the console subsystem (no `-mwindows`).
        #
        # Switching to the GUI subsystem would remove the console window, but it
        # also coincided with the binary failing to start via
        # Explorer/ShellExecute. That was never conclusively attributed to the
        # subsystem — the same symptom appeared with a console build inside the
        # development tree, which is full of symlinks, and never reproduced from
        # an extracted package. Rather than adopt an unverified change, the
        # console stays and `setup_console()` in win_loader.c makes it
        # unobtrusive (hidden on a double-click, QuickEdit off so a click cannot
        # suspend the process, UTF-8 output).
        #
        # `windres` does not search the source directory for the file the `.rc`
        # includes, and a relative include is resolved against the *build*
        # directory.
        target_include_directories(win_loader_exe PRIVATE ${CMAKE_SOURCE_DIR}/..)
        enable_language(RC)
    endfunction()
endif()

# inkview-compat
if(POCKETBOOK)
    set(EXCLUDE_FROM_ALL)
else()
    set(EXCLUDE_FROM_ALL EXCLUDE_FROM_ALL)
endif()
declare_koreader_target(
    inkview-compat TYPE library
    DEPENDS inkview::inkview_517 pthread
    ${EXCLUDE_FROM_ALL}
    SOURCES input/inkview-compat.c
)

# button-listen
if(REMARKABLE)
    set(EXCLUDE_FROM_ALL)
else()
    set(EXCLUDE_FROM_ALL EXCLUDE_FROM_ALL)
endif()
declare_koreader_target(
    button-listen TYPE executable
    ${EXCLUDE_FROM_ALL}
    SOURCES button-listen.c
)

# unpack
#
# Not built for Windows. It links the *static* libarchive, xz, zlib and zstd,
# and that only works where those are built static-only (which is what
# MONOLIBTIC does, on the devices this tool is for). Here the shared build runs
# alongside, so libarchive's static archive is compiled with `-DZLIB_DLL` --
# detected against the import library, and inherited by both targets -- and its
# zlib references become `__imp_inflateEnd` and friends, which need the DLL at
# run time and so defeat the point of a static link.
#
# Nothing needs it: no Lua code invokes it, no Makefile installs it, and it is
# not in the shipped package. Left out rather than linked against a mix of
# static and import libraries.
if(NOT (ANDROID OR APPLE OR EMULATE_READER OR WIN32))
    set(EXCLUDE_FROM_ALL)
else()
    set(EXCLUDE_FROM_ALL EXCLUDE_FROM_ALL)
endif()
declare_koreader_target(
    unpack TYPE executable
    DEPENDS libarchive::libarchive_static xz::lzma_static zlib::z_static zstd::zstd_static m
    ${EXCLUDE_FROM_ALL}
    SOURCES unpack.c
)

# }}}

# MONOLIBTIC. {{{

if(MONOLIBTIC)

    set(DEPENDS)
    foreach(NAME IN LISTS KOREADER_TARGETS)
        if(${NAME}_TYPE STREQUAL "monolibtic" AND NOT ${NAME}_EXCLUDE_FROM_ALL)
            list(APPEND DEPENDS ${NAME} ${${NAME}_DEPENDS})
        endif()
    endforeach()
    if(ANDROID AND IS_DIRECTORY "${ANDROID_LAUNCHER_DIR}")
        list(APPEND DEPENDS android-luajit-launcher::7z)
    endif()
    if(KINDLE)
        list(APPEND DEPENDS openlipclua::libopenlipclua)
    endif()
    if(NOT (APPLE OR EMULATE_READER))
        list(APPEND DEPENDS xz::lzma_static)
    endif()
    declare_koreader_target(
        koreader-monolibtic TYPE library
        DEPENDS ${DEPENDS}
        # We still need to manually add some transitive dependencies because
        # CMake is shit at handling mutiple level of static libraries.
        libarchive::libarchive
        czmq::czmq
        freetype2::freetype
        giflib::gif
        harfbuzz::harfbuzz
        koreader-lfs::koreader-lfs
        leptonica::leptonica
        libjpeg-turbo::turbojpeg
        libk2pdfopt::k2pdfopt
        libressl::crypto
        libressl::ssl
        libzmq::zmq
        lodepng::lodepng
        lpeg::lpeg
        lua-rapidjson::rapidjson
        luasec::ssl
        luasocket::luasocket
        luasocket::mcore
        luasocket::score
        pthread
        sqlite::sqlite3
        turbo::tffi_wrap
        xxhash::xxhash
        zlib::z
        zstd::zstd
        SOURCES monolibtic.cpp
    )

    function(setup_koreader_monolibtic)
        if(APPLE)
            target_link_options(koreader-monolibtic PRIVATE -Wl,-dead_strip,-dead_strip_dylibs)
        else()
            # NOTE: we can't close the group started with `-Wl,--start-group` because
            # there's no way to tell CMake to add the necessary `-Wl,--end-group` at
            # the end of the line, **after** the libraries. (Proper support is only
            # available from 3.24 onward).
            target_link_options(koreader-monolibtic PRIVATE -Wl,-Bsymbolic,--start-group)
        endif()
        set(CDECLS)
        foreach(NAME IN LISTS KOREADER_TARGETS)
            if(${NAME}_TYPE STREQUAL "monolibtic" AND NOT ${NAME}_EXCLUDE_FROM_ALL)
                list(APPEND CDECLS ${NAME}_cdecl)
            endif()
        endforeach()
        if(ANDROID AND IS_DIRECTORY "${ANDROID_LAUNCHER_DIR}")
            list(APPEND CDECLS android-luajit-launcher_cdecl)
        endif()
        if(KINDLE)
            list(APPEND CDECLS openlipclua_cdecl)
        endif()
        if(NOT (APPLE OR EMULATE_READER))
            list(APPEND CDECLS xz_cdecl)
        endif()
        target_exports(koreader-monolibtic CDECLS ${CDECLS}
            crypto_decl
            freetype2_decl
            giflib_decl
            harfbuzz_cdecl
            koptcontext_cdecl
            koreader-lfs_cdecl
            leptonica_cdecl
            libarchive_cdecl
            libwebp_decl
            lodepng_decl
            lpeg_cdecl
            lua-rapidjson_cdecl
            luasec_cdecl
            luasocket_cdecl
            sqlite3_cdecl
            tffi_wrap_cdecl
            turbojpeg_decl
            utf8proc_decl
            xxhash_cdecl
            zeromq_cdecl
            zlib_decl
            zstd_decl
        )
    endfunction()

endif()

# }}}

# vim: foldmethod=marker foldlevel=0
