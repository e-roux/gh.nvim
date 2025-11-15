# gh.nvim

Neovim integration for GitHub CLI (`gh`).

## Overview

This plugin provides Neovim utilities for working with the GitHub CLI, including:
- Async command execution
- JSON-based caching with TTL
- Quickfix integration
- Issue/PR management utilities

## Structure

```
gh.nvim/
├── lua/gh/
│   ├── init.lua       # Main module entry point
│   ├── cache.lua      # Generic caching with TTL support
│   └── cli.lua        # GitHub CLI wrapper functions
├── plugin/
│   └── gh.lua         # Plugin initialization & :Gh command
└── README.md
```

## Features

### Cache Module (`gh.cache`)

Generic JSON-based file cache with TTL support:

```lua
local cache = require("gh.cache")

-- Check if cache is valid
if cache.is_valid("my_key", 300) then -- 300 seconds TTL
  local data = cache.read("my_key")
end

-- Write to cache
cache.write("my_key", { some = "data" })

-- Get or fetch pattern
cache.get_or_fetch("my_key", function(callback)
  -- Fetch data asynchron ously
  fetch_data(function(data)
    callback(data)
  end)
end, 300, function(data)
  -- Use data
end)
```

**Cache location:** `$XDG_CACHE_HOME/nvim/gh/`

### CLI Module (`gh.cli`)

Async GitHub CLI wrapper:

```lua
local cli = require("gh.cli")

-- List issues
cli.list_issues(nil, function(success, issues, error)
  if success then
    vim.print(issues)
  end
end)

-- Get issue details
cli.get_issue(123, nil, function(success, issue, error)
  if success then
    vim.print(issue)
  end
end)

-- Update issue title
cli.update_title(123, "New title", nil, function(success, error)
  -- Handle result
end)
```

### Commands

`:Gh <args>` - Run gh commands asynchronously and populate quickfix list

## Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - For async job execution
- [gh](https://cli.github.com/) - GitHub CLI

## Installation

This plugin is currently part of a personal Neovim configuration.

To extract as standalone:
1. Copy `plugin/gh.nvim/` directory
2. Install as regular Neovim plugin
3. Ensure `gh` CLI is installed and authenticated

## Future Plans

- [ ] Oil.nvim-style buffer editing for issues/PRs
- [ ] PR review workflows
- [ ] Issue templates
- [ ] Comment management
- [ ] Notification integration
- [ ] Tests

## License

TBD
