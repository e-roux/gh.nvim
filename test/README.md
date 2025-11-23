# Test Documentation

## Overview

gh.nvim uses comprehensive testing with unit tests and end-to-end user journey tests.

## Test Structure

### Naming Convention

**Unit Tests**: Mirror source structure
- `lua/gh/cache.lua` → `test/unit/gh/cache_spec.lua`
- `lua/gh/commands/issue.lua` → `test/unit/gh/commands/issue_spec.lua`
- `lua/gh/issues/list.lua` → `test/unit/gh/issues/list_spec.lua`

**E2E Tests**: Organized by user journey topic
- `test/e2e/issue_list_journey_spec.lua`
- `test/e2e/issue_create_journey_spec.lua`
- `test/e2e/command_flow_journey_spec.lua`

```
test/
├── minimal_init.lua                    # Minimal Neovim config
│
├── unit/                               # Unit tests (mirror source)
│   └── gh/
│       ├── cache_spec.lua              # lua/gh/cache.lua
│       ├── config_spec.lua             # lua/gh/config.lua
│       ├── commands/
│       │   └── issue_spec.lua          # lua/gh/commands/issue.lua
│       ├── issues/
│       │   ├── list_spec.lua           # lua/gh/issues/list.lua
│       │   └── create_spec.lua         # lua/gh/issues/create.lua
│       └── utils/
│           └── frontmatter_spec.lua    # lua/gh/utils/frontmatter.lua
│
└── e2e/                                # E2E tests (by journey)
    ├── issue_list_journey_spec.lua     # Browse & view journey
    ├── issue_create_journey_spec.lua   # Create issue journey
    └── command_flow_journey_spec.lua   # Command execution journey
```

## Running Tests

### All Tests
```bash
make test
```

### Unit Tests Only
```bash
make test.unit
```

### E2E Tests Only
```bash
make e2e
```

### Individual Test File
```bash
# Unit test
nvim --headless --noplugin \
  -u test/minimal_init.lua \
  -c "PlenaryBustedFile test/unit/gh/cache_spec.lua"

# E2E journey
nvim --headless --noplugin \
  -u test/minimal_init.lua \
  -c "PlenaryBustedFile test/e2e/issue_list_journey_spec.lua"
```

## Test Patterns

### Mocking

Tests use mocking to avoid real GitHub API calls:

```lua
local cli = require("gh.cli")
local original_fn = cli.list_issues

cli.list_issues = function(repo, opts, callback)
  -- Mock response
  callback(true, mock_data, nil)
end

-- Run test
-- ...

-- Restore
cli.list_issues = original_fn
```

### Async Testing

Tests handle async operations with `vim.wait`:

```lua
local called = false

async_function(function()
  called = true
end)

vim.wait(1000, function() return called end)
assert.is_true(called)
```

### Buffer Testing

Tests verify buffer creation and content:

```lua
-- Create buffer
gh.issues.open_issue_list(nil)
vim.wait(500, function() return false end)

-- Verify buffer
local bufname = vim.api.nvim_buf_get_name(0)
assert.is_true(bufname:match("gh://issues") ~= nil)
assert.are.equal("acwrite", vim.bo.buftype)
```

## User Journeys Tested

### Journey 1: Browse Issues
1. User runs `:Gh issue list`
2. Issue list opens in buffer
3. User sees formatted issues
4. User presses `<CR>` on issue
5. Issue detail opens in split
6. User views issue content

**Tests**: `issue_list_journey_spec.lua`

### Journey 2: Create Issue
1. User runs `:Gh issue create`
2. Template selection appears
3. User selects template
4. Buffer opens with template
5. User fills in content
6. User saves (`:w`)
7. Issue created on GitHub

**Tests**: `issue_create_journey_spec.lua`

### Journey 3: Create Issue From List
1. User browses issue list
2. User presses `<leader>n`
3. New issue buffer opens in split
4. User fills in content
5. User saves
6. New issue appears in list

**Tests**: `issue_create_journey_spec.lua`

### Journey 4: Command Execution
1. User runs commands with flags
2. Command completion works
3. Error handling provides helpful messages

**Tests**: `command_flow_journey_spec.lua`

## Debugging Tests

### Run Single Test
```bash
nvim --headless --noplugin \
  -u test/minimal_init.lua \
  -c "PlenaryBustedFile test/unit/gh/cache_spec.lua"
```

### Interactive Testing
```bash
nvim -u test/minimal_init.lua
:PlenaryBustedFile test/unit/gh/cache_spec.lua
```
