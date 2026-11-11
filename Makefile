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

# pkg-config is optional when LuaJIT follows the usual prefix layout.
ifeq ($(strip $(LUAJIT_CFLAGS)),)
LUAJIT_CFLAGS = -I$(LUAJIT_PREFIX)/include/luajit-2.1
endif

# User-tunable flags. Flags the module cannot build without live in
# MODULE_CFLAGS/MODULE_LDFLAGS so that CFLAGS/LDFLAGS exported by the
# environment (e.g. Homebrew setups) cannot drop -fPIC or -bundle/-shared.
CFLAGS ?= -O2
LDFLAGS ?=
STRICT_CFLAGS ?= $(CFLAGS) -Wall -Wextra -Wpedantic -Werror
MODULE_CFLAGS = -fPIC -std=c99

# The module must not link libluajit: symbols are resolved from the host
# luajit process, otherwise a statically linked luajit ends up with two VMs.
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
MODULE_LDFLAGS = -bundle -undefined dynamic_lookup
else
MODULE_LDFLAGS = -shared
endif

all: ltermbox.so

ltermbox.so: src/termbox.c vendor/termbox.h
	$(CC) $(MODULE_CFLAGS) $(CFLAGS) $(LUAJIT_CFLAGS) -Ivendor -o $@ $< $(MODULE_LDFLAGS) $(LDFLAGS)

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
