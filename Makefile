.PHONY: all build test profile
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
