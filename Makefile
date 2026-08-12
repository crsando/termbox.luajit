.PHONY: all test clean run

LUAJIT ?= luajit
CC ?= cc
LUAJIT_CFLAGS ?= $(shell pkg-config --cflags luajit)
LUAJIT_LIBS ?= $(shell pkg-config --libs luajit)
CFLAGS ?= -O2 -fPIC -std=c99
LDFLAGS ?= -bundle -undefined dynamic_lookup

all: termbox.so

termbox.so: src/termbox_lua.c vendor/termbox2.h
	$(CC) $(CFLAGS) $(LUAJIT_CFLAGS) $(LDFLAGS) -Ivendor -o $@ $< $(LUAJIT_LIBS)

test: termbox.so
	$(LUAJIT) tests/smoke.lua

run: termbox.so
	$(LUAJIT) examples/prompt.lua

clean:
	rm -f termbox.so
