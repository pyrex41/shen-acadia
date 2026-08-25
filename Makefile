ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SHEN_LUA ?= $(ROOT)../shen-lua/bin/shen
SHEN_GO  ?= $(ROOT)../shen-go/.bin/shen-go
BIFROST  ?= bifrost
ACADIA_BIN ?= $(HOME)/bin/acadia
BENCH_N ?= 200

.PHONY: help test test-lua test-go bifrost bench exotic-agree flow gates

help:
	@echo "targets:"
	@echo "  make test      # Shen codec selftest (shen-lua)"
	@echo "  make bifrost   # codec agreement shen-lua/shen-go"
	@echo "  make bench     # Acadia serve vs shen-rel vs Shen encode"
	@echo "  make exotic-agree EXOTIC1_ROOT=/path/to/exotic-1"
	@echo "  make flow      # Shen selection + live Acadia recommendation links"
	@echo "  make gates     # compiler, both Shen ports, Bifrost, live flow"

test: test-lua

test-lua:
	cd "$(ROOT)" && SHEN_FASL=off "$(SHEN_LUA)" --hush-load run-tests.shen

test-go:
	cd "$(ROOT)" && "$(SHEN_GO)" script run-tests.shen

bifrost:
	cd "$(ROOT)" && \
	  SHEN_FASL=off \
	  BIFROST_SHEN_LUA="$(SHEN_LUA)" \
	  BIFROST_SHEN_GO="$(SHEN_GO)" \
	  "$(BIFROST)" --suite ./bifrost.suite.json --impls shen-lua,shen-go

exotic-agree:
	cd "$(ROOT)" && \
	  SHEN_LUA="$(SHEN_LUA)" \
	  SHEN_GO="$(SHEN_GO)" \
	  EXOTIC1_ROOT="$(EXOTIC1_ROOT)" \
	  ./integration/exotic-agree.sh

flow:
	cd "$(ROOT)" && \
	  SHEN_LUA="$(SHEN_LUA)" \
	  SHEN_GO="$(SHEN_GO)" \
	  ACADIA_BIN="$(ACADIA_BIN)" \
	  python3 flow/run.py

gates:
	"$(ACADIA_BIN)" make
	$(MAKE) test
	$(MAKE) test-go
	$(MAKE) bifrost
	$(MAKE) flow

bench:
	cd "$(ROOT)" && \
	  SHEN_LUA="$(SHEN_LUA)" \
	  ACADIA_BIN="$(ACADIA_BIN)" \
	  BENCH_N="$(BENCH_N)" \
	  PYTHONUNBUFFERED=1 python3 bench/run.py
