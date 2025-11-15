# gh.nvim

Neovim integration for GitHub CLI (`gh`) - simple and robust.

## Philosophy

**Keep it simple.** For advanced GitHub features, use the browser. This plugin focuses on:
- Basic issue viewing and editing
- Quick access from Neovim
- Seamless sync via `gh` CLI
- No complex UI, just text buffers

## Overview

This plugin provides Neovim utilities for working with the GitHub CLI, including:
- Oil.nvim-style buffer editing for issues
- Virtual text for issue metadata (labels, assignees, state, dates)
- Async command execution
- In-memory caching with TTL
- Command completion
- Issue/PR management utilities

## Structure

```
gh.nvim/
├── lua/gh/
│   ├── init.lua       # Main module entry point
│   ├── buffer.lua     # Buffer management utilities
│   ├── cache.lua      # In-memory caching with TTL support
│   ├── cli.lua        # GitHub CLI wrapper functions
│   ├── issues.lua     # Issue buffer editing
│   └── types.lua      # Type definitions
├── plugin/
│   └── gh.lua         # Plugin initialization & commands
└── README.md
```

## Features

### Issue List View

```vim
:Gh issue list              " Open issues for current repo
:Gh issue list owner/repo   " Open issues for specific repo
```

The issue list buffer displays issues in an editable table format:
```
# GitHub Issues (edit and :w to save)
# Format: #number │ STATE │ title
#123 │ OPEN │ Fix the navigation bug
#124 │ CLOSED │ Add dark mode support
```

**Actions:**
- Edit titles directly in the buffer
- Change state between OPEN/CLOSED
- Press `<CR>` on an issue to open detail view
- Press `R` to refresh the list
- Save with `:w` to sync changes to GitHub

### Issue Detail View

```vim
:Gh issue view 123              " Open issue #123 for current repo
:Gh issue view 123 owner/repo   " Open issue from specific repo
```

The issue detail buffer shows the full issue with editable content:
```markdown
# Issue title here

Issue body in markdown format.

You can edit both the title and body,
then save with :w to sync to GitHub.
```

**Metadata Display (Virtual Text):**
After the title, you'll see issue metadata in virtual text:
- State (OPEN/CLOSED)
- Author
- Labels
- Assignees
- Created/Updated dates
- URL

**Actions:**
- Edit title (first line after `#`)
- Edit body (everything after the blank line)
- Press `q` to close
- Press `gx` to open issue in browser
- Save with `:w` to sync changes to GitHub

### Command Completion

The `:Gh` command has tab completion for subcommands:

```vim
:Gh <TAB>              " Shows: issue, pr, repo, run, workflow
:Gh issue <TAB>        " Shows: list, view, create, close, reopen
:Gh pr <TAB>           " Shows: list, view, create, checkout, status
```

### Cache Module (`gh.cache`)

In-memory cache with TTL support (session-scoped):

```lua
local cache = require("gh.cache")

-- Check if cache is valid
if cache.is_valid("my_key", 300) then -- 300 seconds TTL
  local data = cache.read("my_key")
end

-- Write to cache
cache.write("my_key", { some = "data" })

-- Get cache statistics
local stats = cache.get_stats()
```

**Note:** Cache is cleared when Neovim restarts.

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
```

### Other GitHub Commands

The `:Gh` command also acts as a passthrough to the GitHub CLI:

```vim
:Gh pr list
:Gh pr checks
:Gh repo view
:Gh run list
```

These commands execute asynchronously and populate the quickfix list with results.

## Dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - For async job execution
- [gh](https://cli.github.com/) - GitHub CLI

## Installation

This plugin is currently part of a personal Neovim configuration.

To extract as standalone:
1. Copy `plugin/gh.nvim/` directory
2. Install as regular Neovim plugin
3. Ensure `gh` CLI is installed and authenticated

## Design Principles

1. **Simplicity over features** - Only implement what makes sense in a text editor
2. **Robust over fancy** - Prefer simple, tested code over complex UI
3. **Browser for complex tasks** - Labels, assignees, reviews → use GitHub web UI
4. **Text-first** - Everything is just text buffers, familiar to Vim users

## Future Plans

- [ ] Basic PR viewing (read-only)
- [ ] Issue creation from template
- [ ] Better error messages
- [ ] More tests

**Not Planned:**
- Complex PR review UI (use browser)
- Label/assignee editing (use browser) 
- Advanced filtering/searching (use `gh` CLI directly)
- Notifications (use browser or `gh` CLI)

## License

TBD
