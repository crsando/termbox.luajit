.PHONY: all test clean run

LUAJIT ?= luajit
CC ?= cc
PKG_CONFIG ?= pkg-config
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

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
LDFLAGS ?= -bundle -undefined dynamic_lookup
else
LDFLAGS ?= -shared
endif

all: ltermbox.so

ltermbox.so: src/termbox.c vendor/termbox.h
	$(CC) $(CFLAGS) $(LUAJIT_CFLAGS) $(LDFLAGS) -Ivendor -o $@ $< $(LUAJIT_LIBS)

test: ltermbox.so
	$(LUAJIT) tests/colors.lua
	$(LUAJIT) tests/smoke.lua

run: ltermbox.so
	$(LUAJIT) examples/prompt.lua

clean:
	rm -f ltermbox.so
