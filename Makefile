.PHONY: all build test zig-test lisp-test lisp-benchmark lisp-profile profile typst-example
.NOTPARALLEL:

RUNS ?= 200
STAT_RUNS ?= 20
LISP_PROFILE_SAMPLES ?= 1500
LISP_PROFILE_DEPTH ?= 4

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

lisp-profile:
	sbcl --script common-lisp/profile.lisp $(LISP_PROFILE_SAMPLES) $(LISP_PROFILE_DEPTH)

profile:
	RUNS=$(RUNS) STAT_RUNS=$(STAT_RUNS) ./etc/profile-linux.sh

typst-example:
	zig build typst-plugin -Doptimize=ReleaseSmall
	typst compile --root . examples/typst-plugin.typ zig-out/typst-plugin.pdf
