#define TB_IMPL
#include "termbox2.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>

static int l_init(lua_State *L) { lua_pushinteger(L, tb_init()); return 1; }
static int l_shutdown(lua_State *L) { (void)L; lua_pushinteger(L, tb_shutdown()); return 1; }
static int l_width(lua_State *L) { (void)L; lua_pushinteger(L, tb_width()); return 1; }
static int l_height(lua_State *L) { (void)L; lua_pushinteger(L, tb_height()); return 1; }
static int l_clear(lua_State *L) { (void)L; lua_pushinteger(L, tb_clear()); return 1; }
static int l_present(lua_State *L) { (void)L; lua_pushinteger(L, tb_present()); return 1; }
static int l_set_cursor(lua_State *L) { tb_set_cursor((int)luaL_checkinteger(L, 1), (int)luaL_checkinteger(L, 2)); return 0; }
static int l_hide_cursor(lua_State *L) { (void)L; tb_set_cursor(-1, -1); return 0; }

static uintattr_t color(const char *name) {
    if (!name || strcmp(name, "default") == 0) return TB_DEFAULT;
    if (strcmp(name, "black") == 0) return TB_BLACK;
    if (strcmp(name, "red") == 0) return TB_RED;
    if (strcmp(name, "green") == 0) return TB_GREEN;
    if (strcmp(name, "yellow") == 0) return TB_YELLOW;
    if (strcmp(name, "blue") == 0) return TB_BLUE;
    if (strcmp(name, "magenta") == 0) return TB_MAGENTA;
    if (strcmp(name, "cyan") == 0) return TB_CYAN;
    if (strcmp(name, "white") == 0) return TB_WHITE;
    return TB_DEFAULT;
}

static int l_set_cell(lua_State *L) {
    int x = (int)luaL_checkinteger(L, 1), y = (int)luaL_checkinteger(L, 2);
    size_t n; const char *s = luaL_checklstring(L, 3, &n);
    const char *fg = luaL_optstring(L, 4, "default"), *bg = luaL_optstring(L, 5, "default");
    uint32_t ch = n ? (unsigned char)s[0] : ' ';
    uintattr_t attrs = lua_toboolean(L, 6) ? TB_BOLD : 0;
    tb_set_cell(x, y, ch, color(fg) | attrs, color(bg));
    return 0;
}

static int l_poll(lua_State *L) {
    struct tb_event event;
    int rv = tb_peek_event(&event, (int)luaL_optinteger(L, 1, 0));
    if (rv < 0) { lua_pushnil(L); return 1; }
    lua_newtable(L);
    if (event.type == TB_EVENT_RESIZE) {
        lua_pushliteral(L, "resize"); lua_setfield(L, -2, "type");
        lua_pushinteger(L, event.w); lua_setfield(L, -2, "width");
        lua_pushinteger(L, event.h); lua_setfield(L, -2, "height");
    } else if (event.type == TB_EVENT_KEY) {
        lua_pushliteral(L, "key"); lua_setfield(L, -2, "type");
        lua_pushinteger(L, event.key); lua_setfield(L, -2, "key");
        lua_pushinteger(L, event.ch); lua_setfield(L, -2, "ch");
        lua_pushinteger(L, event.mod); lua_setfield(L, -2, "mod");
    } else {
        lua_pushliteral(L, "other"); lua_setfield(L, -2, "type");
    }
    return 1;
}

static const luaL_Reg funcs[] = {
    {"init", l_init}, {"shutdown", l_shutdown}, {"width", l_width}, {"height", l_height},
    {"clear", l_clear}, {"present", l_present}, {"set_cursor", l_set_cursor}, {"hide_cursor", l_hide_cursor},
    {"set_cell", l_set_cell}, {"poll", l_poll}, {NULL, NULL}
};

int luaopen_termbox(lua_State *L) {
#if LUA_VERSION_NUM >= 502
    luaL_newlib(L, funcs);
#else
    luaL_register(L, "termbox", funcs);
#endif
    lua_pushinteger(L, TB_EVENT_KEY); lua_setfield(L, -2, "EVENT_KEY");
    lua_pushinteger(L, TB_EVENT_RESIZE); lua_setfield(L, -2, "EVENT_RESIZE");
    lua_pushinteger(L, TB_KEY_ARROW_LEFT); lua_setfield(L, -2, "KEY_ARROW_LEFT");
    lua_pushinteger(L, TB_KEY_ARROW_RIGHT); lua_setfield(L, -2, "KEY_ARROW_RIGHT");
    lua_pushinteger(L, TB_KEY_BACKSPACE); lua_setfield(L, -2, "KEY_BACKSPACE");
    lua_pushinteger(L, TB_KEY_BACKSPACE2); lua_setfield(L, -2, "KEY_BACKSPACE2");
    lua_pushinteger(L, TB_KEY_ENTER); lua_setfield(L, -2, "KEY_ENTER");
    return 1;
}
