.PHONY: all build test zig-test lisp-test lisp-benchmark lisp-profile lisp-format profile typst-example
.NOTPARALLEL:

WIDTH ?= 80
RUNS ?= 200
STAT_RUNS ?= 20
LISP_PROFILE_SAMPLES ?= 1500
LISP_PROFILE_DEPTH ?= 4
LISP_PROFILE_STATISTICS ?= 0

all: build test profile

build:
	zig build

test: zig-test lisp-test

zig-test:
	zig build test

lisp-test:
	XDG_CACHE_HOME=/tmp/zoot-asdf-statistics sbcl --script common-lisp/tests.lisp
	XDG_CACHE_HOME=/tmp/zoot-asdf-statistics sbcl --script common-lisp/sexp-tests.lisp

lisp-benchmark:
	XDG_CACHE_HOME=/tmp/zoot-asdf-statistics sbcl --script common-lisp/benchmark.lisp $(RUNS)

lisp-format:
	XDG_CACHE_HOME=/tmp/zoot-asdf-statistics sbcl --script common-lisp/format-file.lisp $(FILE) $(WIDTH) $(FLAGS)

lisp-profile:
	XDG_CACHE_HOME=/tmp/zoot-asdf-statistics-$(LISP_PROFILE_STATISTICS) ZOOT_STATISTICS=$(LISP_PROFILE_STATISTICS) sbcl --script common-lisp/profile.lisp $(LISP_PROFILE_SAMPLES) $(LISP_PROFILE_DEPTH)

profile:
	RUNS=$(RUNS) STAT_RUNS=$(STAT_RUNS) ./etc/profile-linux.sh

typst-example:
	zig build typst-plugin -Doptimize=ReleaseSmall
	typst compile --root . examples/typst-plugin.typ zig-out/typst-plugin.pdf
