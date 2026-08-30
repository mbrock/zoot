.PHONY: all build test profile typst-example
.NOTPARALLEL:

RUNS ?= 200
STAT_RUNS ?= 20

all: build test profile

build:
	zig build

test:
	zig build test

profile:
	RUNS=$(RUNS) STAT_RUNS=$(STAT_RUNS) ./etc/profile-linux.sh

typst-example:
	zig build typst-plugin -Doptimize=ReleaseSmall
	typst compile --root . examples/typst-plugin.typ zig-out/typst-plugin.pdf
