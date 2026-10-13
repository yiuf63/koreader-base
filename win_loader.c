/* Entry point for the SDL Windows application
 *
 * The Windows counterpart of `osx_loader.c`: a real PE binary is needed to host
 * the SDL application (a Lua script cannot be executed directly there).
 *
 * NOTE: unlike an app bundle, the build tree layout is
 *       `base/build/<machine>/koreader.exe`, so walk up to the directory that
 *       holds `reader.lua` instead of hardcoding a depth.
 */

#include <stdio.h>          // for fprintf, stderr
#include <stdlib.h>         // for exit, EXIT_FAILURE
#include <string.h>         // for strrchr
#include <direct.h>         // for _chdir
#include <windows.h>        // for GetModuleFileName

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#define LOGNAME "Win loader"
#define LANGUAGE "en_US.UTF-8"
#define PLATFORM "KO_MULTIUSER"
#define LUA_ERROR "failed to run lua chunk: %s\n"

/* How far up to look for `reader.lua` before giving up. */
#define MAX_DEPTH 8

static int has_reader_lua(void) {
    FILE *f = fopen("reader.lua", "rb");
    if (!f)
        return 0;
    fclose(f);
    return 1;
}

/* chdir() to the directory holding `reader.lua`, starting from the executable's
 * own directory and walking up a few levels. */
static int chdir_to_project_root(char *path) {
    char *last_slash;
    int depth;

    if (GetModuleFileName(NULL, path, MAX_PATH) == 0) {
        fprintf(stderr, "[%s]: unable to get executable path\n", LOGNAME);
        return 0;
    }

    /* NUL-terminate at the last path separator, dropping the file name. */
    last_slash = strrchr(path, '\\');
    if (!last_slash)
        last_slash = strrchr(path, '/');
    if (!last_slash) {
        fprintf(stderr, "[%s]: unable to get executable directory\n", LOGNAME);
        return 0;
    }
    *last_slash = '\0';

    if (_chdir(path) != 0) {
        fprintf(stderr, "[%s]: unable to chdir to '%s'\n", LOGNAME, path);
        return 0;
    }

    for (depth = 0; depth < MAX_DEPTH; depth++) {
        if (has_reader_lua())
            return 1;
        if (_chdir("..") != 0)
            break;
    }

    fprintf(stderr, "[%s]: unable to find reader.lua\n", LOGNAME);
    return 0;
}

/* Register `dir` as an additional DLL search directory.
 *
 * `SetDllDirectory` only takes a single directory, but `AddDllDirectory` can be
 * called repeatedly (and, unlike PATH, it is what the loader actually consults
 * for `LoadLibraryEx` with `LOAD_LIBRARY_SEARCH_*`, which is what LuaJIT's
 * `package.loadlib` ends up using). */
static void add_dll_directory(const char *dir) {
    wchar_t wide[MAX_PATH];
    if (MultiByteToWideChar(CP_UTF8, 0, dir, -1, wide, MAX_PATH) == 0) {
        fprintf(stderr, "[%s]: unable to convert '%s' to UTF-16\n", LOGNAME, dir);
        return;
    }
    if (!AddDllDirectory(wide))
        fprintf(stderr, "[%s]: AddDllDirectory('%s') failed\n", LOGNAME, dir);
}

/* Make our DLL directories part of the loader search path.
 *
 * The thirdparty DLLs record their dependencies by file name (PE has no soname
 * mechanism, unlike ELF/Mach-O), and the Windows loader resolves those from the
 * executable's directory and the search path only. Without this,
 * `ffi.load`ing `libs/libarchive-13.dll` fails to find the `libz.dll` sitting
 * right next to it, and `require("rapidjson")` (in `common/`) fails to find
 * `lua51.dll`. */
static void setup_dll_search_path(void) {
    static const char *const dirs[] = { "libs", "common" };
    char cwd[MAX_PATH];

    DWORD len = GetCurrentDirectoryA(MAX_PATH, cwd);
    if (len == 0 || len >= MAX_PATH) {
        fprintf(stderr, "[%s]: unable to get the working directory\n", LOGNAME);
        return;
    }

    /* The exe's own directory is searched by default, so only the two
     * subdirectories need registering. `SetDefaultDllDirectories` replaces the
     * default search order, so ask for the user directories *in addition* to
     * the defaults. */
    if (!SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS | LOAD_LIBRARY_SEARCH_USER_DIRS))
        fprintf(stderr, "[%s]: SetDefaultDllDirectories failed\n", LOGNAME);

    for (size_t i = 0; i < sizeof(dirs) / sizeof(dirs[0]); ++i) {
        char dir[MAX_PATH];
        if ((size_t)snprintf(dir, sizeof(dir), "%s\\%s", cwd, dirs[i]) >= sizeof(dir)) {
            fprintf(stderr, "[%s]: path too long for '%s'\n", LOGNAME, dirs[i]);
            continue;
        }
        add_dll_directory(dir);
    }

    char libs[MAX_PATH];
    if ((size_t)snprintf(libs, sizeof(libs), "%s\\libs", cwd) < sizeof(libs)) {
        if (!SetDllDirectoryA(libs))
            fprintf(stderr, "[%s]: unable to set the DLL directory\n", LOGNAME);
    }
}

/* Make the console tolerable.
 *
 * The loader is a console-subsystem binary, so it always has a console. Three
 * things about that are worth fixing:
 *
 * 1. Windows consoles default to **QuickEdit mode**, where the first click
 *    inside the window begins a text selection and *suspends the process* until
 *    it is dismissed. Since the loader writes its startup logging to stdout, a
 *    stray click looks exactly like the application freezing; closing the window
 *    instead kills the process. Turn it off.
 *
 * 2. The console's code page is the system ANSI one (GBK on a Chinese system),
 *    while the application's output is UTF-8, so the log is mojibake. Select the
 *    UTF-8 code page so it is readable.
 *
 * 3. The window itself is noise when the user double-clicked, so it is hidden —
 *    but only then. `GetConsoleProcessList` distinguishes the two cases: a
 *    console created for this process alone (double-click) has one attached
 *    process, while one inherited from a terminal has at least two. Hiding is
 *    reserved for the former, so launching from a shell still shows output.
 */
static void setup_console(void) {
    HWND wnd = GetConsoleWindow();

    /* No console at all (a GUI-subsystem parent): nothing to do. */
    if (wnd == NULL)
        return;

    /* Is this console ours, or one we were launched from? */
    DWORD owners[2] = { 0, 0 };
    DWORD count = GetConsoleProcessList(owners, 2);
    int ours_alone = (count == 1);

    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);

    /* Make a click in the window harmless. */
    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    DWORD mode;
    if (h != INVALID_HANDLE_VALUE && h != NULL && GetConsoleMode(h, &mode)) {
        mode &= ~ENABLE_QUICK_EDIT_MODE;
        mode |= ENABLE_EXTENDED_FLAGS;
        SetConsoleMode(h, mode);
    }

    if (ours_alone)
        ShowWindow(wnd, SW_HIDE);
}

int main(int argc, const char * argv[]) {
    int retval;
    lua_State *L;
    char path[MAX_PATH];

    setup_console();

    if (!chdir_to_project_root(path))
        exit(EXIT_FAILURE);

    setup_dll_search_path();

    _putenv("LC_ALL=" LANGUAGE);
    _putenv(PLATFORM "=1");

    L = luaL_newstate();
    luaL_openlibs(L);

    /* Build `arg` through the C API rather than by generating Lua source:
     * Windows paths contain backslashes, which are escape sequences in a Lua
     * string literal. */
    lua_createtable(L, argc > 0 ? argc - 1 : 0, 0);
    for (int i = 1; i < argc; ++i) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");

    retval = luaL_dofile(L, "reader.lua");
    if (retval)
        fprintf(stderr, LUA_ERROR, lua_tostring(L, -1));

    lua_close(L);
    _putenv("LC_ALL=");
    _putenv(PLATFORM "=");
    return retval;
}
