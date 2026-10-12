/*
    KindlePDFViewer: DjvuLibre abstraction for Lua
    Copyright (C) 2011 Hans-Werner Hilse <hilse@web.de>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#ifndef _DJVU_H
#define _DJVU_H

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

// Symbol visibility
//
// NOTE: `visibility("default")` is an ELF notion and is not enough on Windows:
//       MinGW's linker exports a symbol only if it is marked `dllexport`. That
//       is invisible as long as the target happens to pull in something that
//       trips the linker's "export everything" mode, which is why only this
//       module was affected — it is the one that links a *static* library
//       (djvulibre), so the linker went the explicit-export route and dropped
//       `luaopen_djvu`. `require("libs/libkoreader-djvu")` then failed with
//       "module not found".
#if defined(_WIN32)
#define DLL_PUBLIC __declspec(dllexport)
#else
#define DLL_PUBLIC __attribute__((visibility("default")))
#endif
#define DLL_LOCAL  __attribute__((visibility("hidden")))

DLL_PUBLIC int luaopen_djvu(lua_State *L);

#endif
