include_guard(GLOBAL)

# Directory of this module: `CMAKE_CURRENT_LIST_DIR` is dynamic (it tracks the
# listfile being processed), so it cannot be used from within the functions
# below, which are called from the individual thirdparty spec files.
set(KOREADER_THIRDPARTY_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR})

if(CMAKE_HOST_APPLE)
    # Note: can't use `sed -i "" -e`, because cmake "helpfully"
    # filter-out the empty argument during command invocation…
    set(ISED sh -c "sed -i '' -e \"$@\"" --)
else()
    set(ISED sed -i -e)
endif()

macro(assert_var_defined varName)
    if(NOT DEFINED ${varName})
        message(FATAL_ERROR "${varName} variable not defined!")
    endif()
endmacro()

# Append autotools variables ("VAR=value") to `list`.
function(append_autotools_vars list)
    foreach(var CC CFLAGS CPPFLAGS CXX CXXFLAGS LD LDFLAGS LIBS AR NM RANLIB RC)
        if(DEFINED ${var})
            string(STRIP "${${var}}" value)
            list(APPEND ${list} "${var}=${value}")
        endif()
    endforeach()
    list(APPEND ${list} STRIP=true)
    set(${list} ${${list}} PARENT_SCOPE)
endfunction()

function(set_libname VAR NAME)
    cmake_parse_arguments("" "" "EXT;VERSION" "" ${ARGN})
    if(NOT DEFINED _EXT)
        set(_EXT ${LIB_EXT})
    endif()
    set(NAME lib${NAME} ${_EXT})
    if(DEFINED _VERSION)
        if(ANDROID)
            # No versioning on Android.
        elseif(APPLE)
            list(INSERT NAME 1 .${_VERSION})
        elseif(WIN32)
            list(INSERT NAME 1 -${_VERSION})
        else()
            list(APPEND NAME .${_VERSION})
        endif()
    endif()
    string(CONCAT NAME ${NAME})
    set(${VAR} ${NAME} PARENT_SCOPE)
endfunction()

function(append_install_commands CMD_LIST)
    cmake_parse_arguments("" "" "DESTINATION" "" ${ARGN})
    if(DEFINED _DESTINATION)
        get_filename_component(_DESTINATION ${_DESTINATION} ABSOLUTE BASE_DIR ${OUTPUT_DIR})
    else()
        set(_DESTINATION ${OUTPUT_DIR})
    endif()
    list(APPEND ${CMD_LIST} COMMAND ${CMAKE_COMMAND} -E make_directory ${_DESTINATION})
    list(APPEND ${CMD_LIST} COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_UNPARSED_ARGUMENTS} ${_DESTINATION}/)
    set(${CMD_LIST} ${${CMD_LIST}} PARENT_SCOPE)
endfunction()

function(append_binary_install_command CMD_LIST)
    cmake_parse_arguments("" "" "DESTINATION" "" ${ARGN})
    if(DEFINED _DESTINATION)
        get_filename_component(_DESTINATION ${_DESTINATION} ABSOLUTE BASE_DIR ${OUTPUT_DIR})
    else()
        set(_DESTINATION ${OUTPUT_DIR})
    endif()
    list(APPEND ${CMD_LIST} COMMAND ${CMAKE_COMMAND} -E make_directory ${_DESTINATION})
    foreach(SRC IN LISTS _UNPARSED_ARGUMENTS)
        get_filename_component(DST ${SRC} NAME)
        set(DST ${_DESTINATION}/${DST})
        if(WIN32)
            # MinGW/PE binaries: the ELF-style debug-info splitting below does
            # not apply (`--add-gnu-debuglink` is ELF-only), so just copy.
            list(APPEND ${CMD_LIST} COMMAND ${CMAKE_COMMAND} -E copy_if_different ${SRC} ${DST})
        elseif(APPLE)
            list(APPEND ${CMD_LIST} COMMAND dsymutil ${SRC} -o ${DST}.dSYM)
            list(APPEND ${CMD_LIST} COMMAND ${STRIP} -x ${SRC} -o ${DST})
        else()
            list(APPEND ${CMD_LIST} COMMAND ${OBJCOPY} --only-keep-debug ${SRC} ${DST}.dbg)
            list(APPEND ${CMD_LIST} COMMAND ${OBJCOPY} --add-gnu-debuglink=${DST}.dbg --strip-unneeded ${SRC} ${DST})
        endif()
        list(APPEND ${CMD_LIST} COMMAND chmod +x ${DST})
    endforeach()
    set(${CMD_LIST} ${${CMD_LIST}} PARENT_SCOPE)
endfunction()

function(append_shared_lib_install_commands CMD_LIST)
    set_libname(LIB ${ARGN})
    if(WIN32)
        # MinGW/PE: thirdparty projects do not consistently install their DLL
        # under the `lib<name>-<version>.dll` name we expect in `lib/`: CMake-
        # based ones tend to install an unversioned `lib<name>.dll` into `bin/`
        # (unlike libtool, which does use the versioned name). Look in both
        # places, under both names, and install under our canonical name.
        string(REGEX REPLACE "-[0-9][0-9.]*(\\.[A-Za-z0-9]+)$" "\\1" LIB_ALT ${LIB})
        set(_DST ${OUTPUT_DIR}/libs/${LIB})
        list(APPEND ${CMD_LIST} COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}/libs)
        list(APPEND ${CMD_LIST} COMMAND sh ${KOREADER_THIRDPARTY_MODULES_DIR}/install_lib.sh ${_DST}
            ${STAGING_DIR}/lib/${LIB}
            ${STAGING_DIR}/bin/${LIB}
            ${STAGING_DIR}/lib/${LIB_ALT}
            ${STAGING_DIR}/bin/${LIB_ALT}
            # Some projects never install their DLL at all (lunasvg only installs
            # the import library and headers), so also look in their build tree.
            ${BINARY_DIR}/${LIB}
            ${BINARY_DIR}/lib/${LIB}
            ${BINARY_DIR}/src/${LIB}
            ${BINARY_DIR}/${LIB_ALT}
            ${BINARY_DIR}/lib/${LIB_ALT}
            ${BINARY_DIR}/src/${LIB_ALT}
        )
        # Point the import archives at the canonical name, so anything linked from
        # here on records `lib<name>-<version>.dll` in its import table instead of
        # the producer's own spelling.
        #
        # PE resolves dependencies by literal file name, so a dependent that links
        # against `libz.dll.a` asks for `libz.dll` at run time — while the frontend
        # asks `ffi/loadlib.lua` for `libz-1.dll`. Both had to be shipped, and
        # `install_lib.sh` hard-links them so the build tree stores one copy; a zip
        # cannot store hard links, so the archive carried two (137 MB over 15
        # libraries). With the archives rewritten there is one name, and one file.
        #
        # `BINARY_DIR` is searched as well as the staging directory: a project that
        # links its own libraries (libwebp does) uses the archive in its build
        # tree, not the installed copy, so both have to be rewritten or the
        # project's own libraries keep importing the old spelling.
        list(APPEND ${CMD_LIST} COMMAND sh ${KOREADER_THIRDPARTY_MODULES_DIR}/record_canonical_implib.sh ${_DST}
            ${STAGING_DIR}/lib ${BINARY_DIR} ${BINARY_DIR}/lib
        )
    else()
        append_binary_install_command(${CMD_LIST} ${STAGING_DIR}/lib/${LIB} DESTINATION ${OUTPUT_DIR}/libs)
    endif()
    set(${CMD_LIST} ${${CMD_LIST}} PARENT_SCOPE)
endfunction()

if(APPLE)
    function(append_shared_lib_fix_commands CMD_LIST)
        cmake_parse_arguments("" "ID;RPATH" "" "" ${ARGN})
        set_libname(LIB ${_UNPARSED_ARGUMENTS})
        list(APPEND ${CMD_LIST} COMMAND install_name_tool)
        if(_ID)
            list(APPEND ${CMD_LIST} -id @rpath/${LIB})
        endif()
        if(_RPATH)
            list(APPEND ${CMD_LIST} -add_rpath @executable_path/libs -add_rpath @executable_path/../koreader/libs)
        endif()
        list(APPEND ${CMD_LIST} ${STAGING_DIR}/lib/${LIB})
        set(${CMD_LIST} ${${CMD_LIST}} PARENT_SCOPE)
    endfunction()
endif()

function(append_tree_install_commands CMD_LIST SRC DST)
    get_filename_component(DST ${DST} ABSOLUTE BASE_DIR ${OUTPUT_DIR})
    list(APPEND ${CMD_LIST} COMMAND ${CMAKE_COMMAND} -E)
    if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.26")
        list(APPEND ${CMD_LIST} copy_directory_if_different)
    else()
        list(APPEND ${CMD_LIST} copy_directory)
    endif()
    set(${CMD_LIST} ${${CMD_LIST}} ${SRC} ${DST} PARENT_SCOPE)
endfunction()

function(target_exports TARGET)
    cmake_parse_arguments("" "" "FILELIST_VAR;WRITE_TO_FILE" "CDECLS" ${ARGN})
    if(NOT _CDECLS)
        message(FATAL_ERROR "missing CDECLS argument")
    endif()
    set(FILELIST)
    foreach(F IN LISTS _CDECLS)
        set(F ${BASE_DIR}/ffi-cdecl/${F}.c)
        if(NOT EXISTS ${F})
            message(FATAL_ERROR "no such FFI cdecl file: ${F}")
        endif()
        list(APPEND FILELIST ${F})
    endforeach()
    if(DEFINED _FILELIST_VAR)
        set(${_FILELIST_VAR} ${FILELIST} PARENT_SCOPE)
    endif()
    if(DEFINED _WRITE_TO_FILE)
        set(FNAME ${_WRITE_TO_FILE})
    else()
        set(FNAME ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_exports.cmake)
    endif()
    set(LINES
        "add_custom_command("
        "    COMMAND ${BASE_DIR}/utils/gen_linker_exports.sh ${LD} ${TARGET}.link_args ${TARGET}.link_exports ${FILELIST}"
        "    OUTPUT ${TARGET}.link_args ${TARGET}.link_exports"
        "    DEPENDS ${BASE_DIR}/utils/gen_linker_exports.sh ${FILELIST}"
        "    VERBATIM"
        ")"
        "add_custom_target(${TARGET}-link-deps DEPENDS ${TARGET}.link_args ${TARGET}.link_exports)"
        "target_link_options(${TARGET} PRIVATE -Wl,@${TARGET}.link_args)"
        "add_dependencies(${TARGET} ${TARGET}-link-deps)"
        "set_target_properties(${TARGET} PROPERTIES LINK_DEPENDS \"${TARGET}.link_args$<SEMICOLON>${TARGET}.link_exports\")"
    )
    list(JOIN LINES "\n" LINES)
    file(WRITE ${FNAME} "${LINES}\n")
    if(NOT DEFINED _WRITE_TO_FILE)
        include(${FNAME})
    endif()
endfunction()

# Set ${VAR} to the path ${PATH} relative to ${BASE_DIR}
# (or ${PATH} unchanged if ${PATH} if not under ${BASE_DIR}).
function(get_relative_path PATH BASE_DIR VAR)
    string(FIND "${PATH}" "${BASE_DIR}/" POS)
    if(POS EQUAL "0")
        string(LENGTH "${BASE_DIR}/" LEN)
        string(SUBSTRING "${PATH}" ${LEN} -1 ${VAR})
    else()
        set(${VAR} "${PATH}")
    endif()
    set(${VAR} "${${VAR}}" PARENT_SCOPE)
endfunction()

function(find_compiler_lib_path VAR LIB)
    cmake_parse_arguments("" "REQUIRED" "" "" ${ARGN})
    if(DEFINED CACHE{${VAR}})
        return()
    endif()
    if(DEFINED CACHE{COMPILER_LIBRARIES_SEARCH_PATHS})
        set(SEARCH_PATHS ${COMPILER_LIBRARIES_SEARCH_PATHS})
    else()
        execute_process(COMMAND ${CMAKE_C_COMPILER} -print-search-dirs RESULT_VARIABLE RET OUTPUT_VARIABLE OUT)
        if(NOT RET EQUAL 0 OR NOT OUT MATCHES "\nlibraries: =([^\n]+)\n")
          message(FATAL_ERROR "could not find compiler search paths for libraries")
        endif()
        string(REPLACE ":" ";" SEARCH_PATHS ${CMAKE_MATCH_1})
        set(COMPILER_LIBRARIES_SEARCH_PATHS ${SEARCH_PATHS} CACHE INTERNAL "compiler search paths for libraries")
    endif()
    if(DEFINED _UNPARSED_ARGUMENTS)
        set(SEARCH_PATHS ${_UNPARSED_ARGUMENTS} ${SEARCH_PATHS})
    endif()
    unset(LIB_PATH CACHE)
    find_library(
        LIB_PATH
        NAMES ${LIB}
        PATHS ${SEARCH_PATHS}
        NO_DEFAULT_PATH NO_PACKAGE_ROOT_PATH NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH NO_CMAKE_INSTALL_PREFIX NO_CMAKE_FIND_ROOT_PATH
    )
    if(NOT LIB_PATH)
        if(_REQUIRED)
            message(FATAL_ERROR "Could not find ${LIB} full path!")
        endif()
        message(STATUS "Looking for ${LIB}: not found")
    else()
        message(STATUS "Looking for ${LIB}: ${LIB_PATH}")
    endif()
    set(${VAR} ${LIB_PATH} CACHE INTERNAL "${LIB} full path")
endfunction()

function(find_executable VAR NAME BINARY VERSION_ARG)
    cmake_parse_arguments("" "REQUIRED" "" "" ${ARGN})
    if(_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "unparsed arguments: ${_UNPARSED_ARGUMENTS}")
    endif()
    if(DEFINED CACHE{${VAR}})
        return()
    endif()
    find_program(${VAR} ${BINARY})
    if(NOT ${VAR})
        if(_REQUIRED)
            message(FATAL_ERROR "Could not find ${NAME} using the following names: ${BINARY}")
        endif()
        message(STATUS "Looking for ${NAME}: not found")
        return()
    endif()
    execute_process(COMMAND ${${VAR}} ${VERSION_ARG} OUTPUT_VARIABLE VERSION OUTPUT_STRIP_TRAILING_WHITESPACE)
    string(REGEX MATCH "(^|[ \n])([0-9][.0-9]*)([\n ]|$)" VERSION "${VERSION}")
    message(STATUS "Looking for ${NAME}: ${${VAR}} (version ${CMAKE_MATCH_2})")
endfunction()

function(check_libc_fn_exists NAME HEADER VAR)
    cmake_parse_arguments("" "REQUIRED" "" "" ${ARGN})
    if(_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "unparsed arguments: ${_UNPARSED_ARGUMENTS}")
    endif()
    if(DEFINED CACHE{${VAR}})
        return()
    endif()
    set(CMAKE_REQUIRED_QUIET TRUE)
    message(STATUS "Looking for ${NAME} in ${HEADER}")
    unset(${VAR}_DECL CACHE)
    check_symbol_exists(${NAME} ${HEADER} ${VAR}_DECL)
    if(${VAR}_DECL)
        set(FOUND "found")
    else()
        set(FOUND "not found")
    endif()
    message(STATUS "Looking for ${NAME} in ${HEADER} - ${FOUND}")
    message(STATUS "Looking for ${NAME} in libc")
    unset(${VAR}_FUNC CACHE)
    check_function_exists(${NAME} ${VAR}_FUNC)
    if(${VAR}_FUNC)
        set(FOUND "found")
    else()
        set(FOUND "not found")
    endif()
    message(STATUS "Looking for ${NAME} in libc - ${FOUND}")
    if(${VAR}_DECL AND ${VAR}_FUNC)
        set(${VAR} TRUE CACHE INTERNAL "${VAR} available")
    else()
        set(${VAR} NOTFOUND CACHE INTERNAL "${VAR} available")
    endif()
endfunction()
