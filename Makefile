.PHONY: all check-deps test check clean run install

LUAJIT ?= luajit
CC ?= cc
PKG_CONFIG ?= pkg-config
PREFIX ?= /usr/local
DESTDIR ?=
LUA_LIBDIR ?= $(PREFIX)/lib/lua/5.1
LUA_SHAREDIR ?= $(PREFIX)/share/lua/5.1
LUAJIT_PREFIX ?= $(shell command -v $(LUAJIT) >/dev/null 2>&1 && dirname "$$(dirname "$$(command -v $(LUAJIT))")")
LUAJIT_CFLAGS ?= $(shell $(PKG_CONFIG) --cflags luajit 2>/dev/null)
LUAJIT_LIBS ?= $(shell $(PKG_CONFIG) --libs luajit 2>/dev/null)

# pkg-config is optional when LuaJIT follows the usual prefix layout.
ifeq ($(strip $(LUAJIT_CFLAGS)),)
LUAJIT_CFLAGS = -I$(LUAJIT_PREFIX)/include/luajit-2.1
endif
ifeq ($(strip $(LUAJIT_LIBS)),)
LUAJIT_LIBS = -L$(LUAJIT_PREFIX)/lib -lluajit-5.1
endif

CFLAGS ?= -O2 -fPIC -std=c99
STRICT_CFLAGS ?= $(CFLAGS) -Wall -Wextra -Wpedantic -Werror

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
LDFLAGS ?= -bundle -undefined dynamic_lookup
else
LDFLAGS ?= -shared
endif

all: ltermbox.so

ltermbox.so: src/termbox.c vendor/termbox.h
	$(CC) $(CFLAGS) $(LUAJIT_CFLAGS) $(LDFLAGS) -Ivendor -o $@ $< $(LUAJIT_LIBS)

check-deps:
	$(LUAJIT) -e 'assert(require("lua-utf8")); assert(require("luv"))'

test: ltermbox.so check-deps
	$(LUAJIT) tests/dependencies.lua
	$(LUAJIT) tests/colors.lua
	$(LUAJIT) tests/text.lua
	$(LUAJIT) tests/markdown.lua
	$(LUAJIT) tests/layout.lua
	$(LUAJIT) tests/terminal.lua
	$(LUAJIT) tests/runtime.lua
	$(LUAJIT) tests/smoke.lua

check:
	$(MAKE) -B CFLAGS="$(STRICT_CFLAGS)" ltermbox.so
	$(MAKE) test

run: ltermbox.so check-deps
	$(LUAJIT) examples/prompt.lua

install: ltermbox.so
	install -d $(DESTDIR)$(LUA_LIBDIR) $(DESTDIR)$(LUA_SHAREDIR)/tui
	install -m 755 ltermbox.so $(DESTDIR)$(LUA_LIBDIR)/ltermbox.so
	install -m 644 lib/tui/*.lua $(DESTDIR)$(LUA_SHAREDIR)/tui/

clean:
	rm -f ltermbox.so
