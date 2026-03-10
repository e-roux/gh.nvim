# Project Makefile
# Standard interface: sync, fmt, lint, typecheck, test, check, qa, clean, help
SHELL := /bin/bash
.SILENT:
.DEFAULT_GOAL := help

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

NVIM ?= nvim
GIT ?= git
STYLUA := $(shell command -v stylua 2>/dev/null)
LUACHECK := $(shell command -v luacheck 2>/dev/null)

RUNTIME_DIR ?= test/runtime
PLENARY_DIR ?= $(RUNTIME_DIR)/plenary.nvim
TEST_DIR ?= test
LUA_DIR ?= lua

#------------------------------------------------------------------------------
# Phony Targets Declaration
#------------------------------------------------------------------------------

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test test.unit test.integration test.e2e test.watch
.PHONY: doc doc.build doc.serve build

#------------------------------------------------------------------------------
# High-Level Targets
#------------------------------------------------------------------------------

check: fmt lint typecheck
qa: check test
test: test.unit test.e2e

#------------------------------------------------------------------------------
# Installation & Dependencies
#------------------------------------------------------------------------------

sync: plenary.init

plenary.init:
	if [ ! -d "$(PLENARY_DIR)" ]; then \
		printf "🔄 Cloning plenary.nvim...\n"; \
		mkdir -p "$(RUNTIME_DIR)"; \
		$(GIT) clone --depth 1 --quiet \
			https://github.com/nvim-lua/plenary.nvim "$(PLENARY_DIR)"; \
		printf "✅ Plenary cloned\n"; \
	fi

#------------------------------------------------------------------------------
# Code Quality
#------------------------------------------------------------------------------

fmt:
ifdef STYLUA
	printf "🔄 Formatting Lua files with stylua...\n"
	$(STYLUA) $(LUA_DIR) plugin
	printf "✅ Formatting complete\n"
else
	printf "❌ stylua not found\n"
	printf "   Install with: cargo install stylua\n"
	exit 1
endif

lint:
ifdef LUACHECK
	printf "🔄 Linting Lua files with luacheck...\n"
	$(LUACHECK) $(LUA_DIR) plugin --globals vim
	printf "✅ Linting complete\n"
else
	printf "⚠️  luacheck not found, skipping\n"
	printf "   Install with: luarocks install luacheck\n"
endif

typecheck:
	printf "⚠️  Typecheck not implemented for Lua, skipping...\n"

#------------------------------------------------------------------------------
# Testing
#------------------------------------------------------------------------------

test.unit: plenary.init
	printf "🧪 Running unit tests...\n"
	test_files=$$(find $(TEST_DIR)/unit -name '*_spec.lua' -type f 2>/dev/null); \
	if [ -n "$$test_files" ]; then \
		for file in $$test_files; do \
			printf "  Testing: $$file\n"; \
			$(NVIM) --headless --noplugin \
				-u test/minimal_init.lua \
				-c "PlenaryBustedFile $$file"; \
		done; \
		printf "✅ Unit tests complete\n"; \
	else \
		printf "⚠️  No unit test files found in $(TEST_DIR)/unit\n"; \
	fi

test.integration:
	printf "⚠️  Integration tests not implemented, skipping...\n"

test.e2e: plenary.init
	printf "🚀 Running E2E tests (user journeys)...\n"
	test_files=$$(find $(TEST_DIR)/e2e -maxdepth 1 -name '*_journey_spec.lua' -type f 2>/dev/null); \
	if [ -n "$$test_files" ]; then \
		for file in $$test_files; do \
			printf "  Journey: $$file\n"; \
			$(NVIM) --headless --noplugin \
				-u test/minimal_init.lua \
				-c "PlenaryBustedFile $$file"; \
		done; \
		printf "✅ E2E tests complete\n"; \
	else \
		printf "⚠️  No E2E test files found in $(TEST_DIR)/e2e\n"; \
	fi

test.watch:
	printf "❌ test.watch not supported for Plenary tests\n"
	exit 1

#------------------------------------------------------------------------------
# Documentation
#------------------------------------------------------------------------------

doc.build:
	$(NVIM) --headless -c "helptags doc" -c "q"
	printf "✅ Documentation tags built\n"

doc.serve: doc.build
	$(NVIM) -c "help gh"

doc: doc.build

#------------------------------------------------------------------------------
# Build
#------------------------------------------------------------------------------

build:
	printf "⚠️  No build step needed for Lua plugin\n"

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

clean:
	printf "🧹 Cleaning artifacts...\n"
	rm -rf .luacheckcache
	printf "✅ Clean complete\n"

distclean: clean
	printf "🧹 Deep clean...\n"
	rm -rf "$(RUNTIME_DIR)"
	printf "✅ Distclean complete\n"

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

help:
	printf "\033[36m"
	printf "███╗   ███╗ █████╗ ██╗  ██╗███████╗\n"
	printf "████╗ ████║██╔══██╗██║ ██╔╝██╔════╝\n"
	printf "██╔████╔██║███████║█████╔╝ █████╗  \n"
	printf "██║╚██╔╝██║██╔══██║██╔═██╗ ██╔══╝  \n"
	printf "██║ ╚═╝ ██║██║  ██║██║  ██╗███████╗\n"
	printf "╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync            - Install dependencies (plenary)\n"
	printf "\n"
	printf "\033[1;35mDevelopment:\033[0m\n"
	printf "  fmt             - Format code with stylua\n"
	printf "  lint            - Lint and auto-fix with luacheck\n"
	printf "  typecheck       - Validate types (no-op)\n"
	printf "  check           - fmt + lint + typecheck\n"
	printf "  qa              - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTesting:\033[0m\n"
	printf "  test            - Run all tests (unit + e2e)\n"
	printf "  test.unit       - Unit tests only\n"
	printf "  test.integration - Integration tests (no-op)\n"
	printf "  test.e2e        - End-to-end tests (journeys)\n"
	printf "  test.watch      - Tests in watch mode (not supported)\n"
	printf "\n"
	printf "\033[1;35mDocumentation:\033[0m\n"
	printf "  doc.build       - Build documentation tags\n"
	printf "  doc.serve       - Serve documentation locally\n"
	printf "\n"
	printf "\033[1;35mBuild:\033[0m\n"
	printf "  build           - Build project (no-op)\n"
	printf "\n"
	printf "\033[1;35mCleanup:\033[0m\n"
	printf "  clean           - Remove build artifacts\n"
	printf "  distclean       - Deep clean (includes runtime)\n"
