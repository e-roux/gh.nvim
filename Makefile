SHELL := /bin/sh
.DEFAULT_GOAL := all
.SILENT:

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

.PHONY: all test fmt lint clean help
.PHONY: plenary.init plenary.run plenary.clean
.PHONY: stylua.run luacheck.run

#------------------------------------------------------------------------------
# High-Level Targets
#------------------------------------------------------------------------------

all: test

test: plenary.run

fmt: stylua.run

lint: luacheck.run

#------------------------------------------------------------------------------
# Testing
#------------------------------------------------------------------------------

plenary.init:
	if [ ! -d "$(PLENARY_DIR)" ]; then \
		printf "🔄 Cloning plenary.nvim...\n"; \
		mkdir -p "$(RUNTIME_DIR)"; \
		$(GIT) clone --depth 1 --quiet \
			https://github.com/nvim-lua/plenary.nvim "$(PLENARY_DIR)"; \
		printf "✅ Plenary cloned\n"; \
	fi

plenary.run: plenary.init
	test_files=$$(find $(TEST_DIR) -maxdepth 1 -name '*_spec.lua' -o -name 'test_*.lua' 2>/dev/null | grep -v runtime); \
	if [ -n "$$test_files" ]; then \
		printf "🔄 Running tests with plenary...\n"; \
		for file in $$test_files; do \
			$(NVIM) --headless --noplugin \
				-u test/minimal_init.lua \
				-c "PlenaryBustedFile $$file"; \
		done; \
		printf "✅ Tests complete\n"; \
	else \
		printf "⚠️  No test files found in $(TEST_DIR)\n"; \
		printf "⚠️  Create test files with *_spec.lua or test_*.lua naming\n"; \
	fi

plenary.clean:
	if [ -d "$(RUNTIME_DIR)" ]; then \
		printf "🧹 Removing plenary runtime...\n"; \
		rm -rf "$(RUNTIME_DIR)"; \
		printf "✅ Plenary runtime removed\n"; \
	fi

#------------------------------------------------------------------------------
# Formatting
#------------------------------------------------------------------------------

stylua.run:
ifdef STYLUA
	printf "🔄 Formatting Lua files with stylua...\n"
	$(STYLUA) $(LUA_DIR) plugin
	printf "✅ Formatting complete\n"
else
	printf "❌ stylua not found\n"
	printf "   Install with: cargo install stylua\n"
	exit 1
endif

#------------------------------------------------------------------------------
# Linting
#------------------------------------------------------------------------------

luacheck.run:
ifdef LUACHECK
	printf "🔄 Linting Lua files with luacheck...\n"
	$(LUACHECK) $(LUA_DIR) plugin --globals vim
	printf "✅ Linting complete\n"
else
	printf "⚠️  luacheck not found, skipping\n"
	printf "   Install with: luarocks install luacheck\n"
endif

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

clean: plenary.clean
	printf "🧹 Cleaning artifacts...\n"
	rm -rf .luacheckcache
	printf "✅ Clean complete\n"

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

help:
	printf "gh.nvim Makefile\n\n"
	printf "Usage: make [target] [VAR=val]\n\n"
	printf "Targets:\n"
	printf "  all          - Run all tests (default)\n"
	printf "  test         - Run plenary tests\n"
	printf "  fmt          - Format Lua files with stylua\n"
	printf "  lint         - Lint Lua files with luacheck\n"
	printf "  clean        - Remove generated files and caches\n"
	printf "  help         - Show this help message\n\n"
	printf "Namespaced Targets:\n"
	printf "  plenary.init - Clone plenary.nvim for testing\n"
	printf "  plenary.run  - Run plenary test suite\n"
	printf "  plenary.clean - Remove plenary runtime\n"
	printf "  stylua.run   - Run stylua formatter\n"
	printf "  luacheck.run - Run luacheck linter\n\n"
	printf "Variables:\n"
	printf "  NVIM         - Neovim binary (default: nvim)\n"
	printf "  GIT          - Git binary (default: git)\n"
	printf "  RUNTIME_DIR  - Test runtime directory (default: test/runtime)\n"
	printf "  TEST_DIR     - Test directory (default: test)\n"
