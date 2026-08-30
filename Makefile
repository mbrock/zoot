.PHONY: all build test zig-test lisp-test lisp-benchmark profile typst-example
.NOTPARALLEL:

RUNS ?= 200
STAT_RUNS ?= 20

all: build test profile

build:
	zig build

test: zig-test lisp-test

zig-test:
	zig build test

lisp-test:
	sbcl --script common-lisp/tests.lisp

lisp-benchmark:
	sbcl --script common-lisp/benchmark.lisp $(RUNS)

profile:
	RUNS=$(RUNS) STAT_RUNS=$(STAT_RUNS) ./etc/profile-linux.sh

typst-example:
	zig build typst-plugin -Doptimize=ReleaseSmall
	typst compile --root . examples/typst-plugin.typ zig-out/typst-plugin.pdf
