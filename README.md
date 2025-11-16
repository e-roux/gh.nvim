# gh.nvim

**⚠️ Work In Progress** - This plugin is under active development and APIs may change.

Neovim integration for GitHub CLI (`gh`).

## Overview

Neovim utilities for working with the GitHub CLI, focusing on basic issue/PR viewing and editing with quick access from your editor.

**Features:**
- **Issue/PR browsing:** Buffer-based lists with Oil-style editing
- **Issue editing:** Text buffer editing with seamless sync via `gh` CLI
- Async command execution via GraphQL or JSON
- In-memory caching with TTL
- Command completion

**Inspired by:** [Snacks.nvim](https://github.com/folke/snacks.nvim) rendering style

## Features

### Data Source

gh.nvim supports two modes for fetching GitHub data:

- **`"json"`** (default): Uses `gh` CLI with JSON output
  - More reliable, works everywhere `gh` works
  - Slightly slower due to JSON parsing
  
- **`"api"`**: Uses GraphQL API via `gh api graphql`
  - Faster data fetching
  - More efficient for large datasets

**Configuration Example:**

```lua
vim.g.gh_opts = {
  data_source = "json",  -- or "api"
  issue_detail = {
    reuse_window = true,
    split_direction = "auto",  -- "auto", "horizontal", or "vertical"
  }
}
```

See [Configuration](#configuration) section for all available options.

### Issue List View

```vim
:Gh issue list                           " Open issues for current repo (open issues only, default)
:Gh issue list --state all               " All issues (open + closed)
:Gh issue list --state closed            " Closed issues only
:Gh issue list --limit 50                " Limit to 50 issues
:Gh issue list --repo owner/repo         " Issues from specific repo
:Gh issue list --state all --limit 100   " Combine flags
```

**Note:** Like `gh` CLI, `:Gh issue list` shows **open issues only** by default. Use `--state all` to see both open and closed issues.

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
:Gh issue view 123                  " Open issue #123 for current repo
:Gh issue view 123 --repo owner/repo " Open issue from specific repo
```

The issue detail buffer shows the full issue with editable content:
```markdown
# Issue title here

Issue body in markdown format.

You can edit both the title and body,
then save with :w to sync to GitHub.
```

**Metadata Display (Virtual Text):**
After the title, you'll see issue metadata rendered as virtual text with badges and colors:
- State (OPEN/CLOSED) with badges
- Author
- Labels with color-coded badges
- Assignees
- Created/Updated dates (relative time)
- URL

**Actions:**
- Edit title (first line after `#`)
- Edit body (everything after the blank line)
- Press `q` to close
- Press `gx` to open issue in browser
- Save with `:w` to sync changes to GitHub

### Command Completion

The `:Gh` command has tab completion for subcommands and flags:

```vim
:Gh <TAB>                      " Shows: issue, pr, repo, run, workflow
:Gh issue <TAB>                " Shows: list, view, create, close, reopen
:Gh pr <TAB>                   " Shows: list, view, create, checkout, status

" Flag completion
:Gh issue list -<TAB>          " Shows: --state, -s, --limit, -L, --repo, -R
:Gh issue list --state <TAB>   " Shows: open, closed, all
:Gh issue view 123 -<TAB>      " Shows: --repo, -R
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

#### Pull Request Support

**Pull request commands:**
```vim
:Gh pr list                           " List pull requests (not yet implemented)
:Gh pr view 456                       " View/edit PR #456 (not yet implemented)
```

**Note:** PR support is planned for a future release.

#### GitHub CLI Passthrough

The `:Gh` command also acts as a passthrough to the GitHub CLI:

```vim
:Gh pr checks
:Gh repo view
:Gh run list
```

These commands execute asynchronously and populate the quickfix list with results.

## Dependencies

### Required
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - For async job execution
- [gh](https://cli.github.com/) - GitHub CLI

## Installation

### Prerequisites

- Neovim 0.8+ (tested with 0.10+)
- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Using lazy.nvim

```lua
{
  "e-roux/gh.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
```

Add to your `init.lua`:
```lua
vim.g.gh_opts = {}  -- Use defaults, or pass custom config (see Configuration)
```

### Using packer.nvim

```lua
use {
  "e-roux/gh.nvim",
  requires = { 
    "nvim-lua/plenary.nvim",
  },
}
```

Add to your `init.lua`:
```lua
vim.g.gh_opts = {}  -- Use defaults, or pass custom config (see Configuration)
```

### Manual Installation (for Neovim < 0.12)

1. Clone this repository to your Neovim config directory:
   ```bash
   git clone https://github.com/e-roux/gh.nvim ~/.config/nvim/pack/plugins/start/gh.nvim
   ```

2. Install plenary.nvim if not already installed

3. Add to your `init.lua`:
   ```lua
   vim.g.gh_opts = {}  -- Use defaults, or pass custom config (see Configuration)
   ```

4. Ensure `gh` CLI is installed and authenticated:
   ```bash
   gh auth login
   ```

## Configuration

Configuration is passed via `vim.g.gh_opts` and automatically merged with defaults when the plugin loads.

```lua
vim.g.gh_opts = {
  -- Data source for GitHub API calls
  -- "json" (default): Uses gh CLI with JSON output (reliable)
  -- "api": Uses GraphQL API via gh api (faster)
  data_source = "json",
  
  -- Issue detail view options
  issue_detail = {
    reuse_window = true,           -- Reuse existing issue detail window
                                   -- When true: opening a new issue replaces the current issue detail window
                                   -- When false: each issue opens in a new split
    split_direction = "auto"       -- Split direction for issue detail windows:
                                   -- "auto" (default): Automatically choose based on window width
                                   --                   (vertical if width >= 120 columns, horizontal otherwise)
                                   -- "horizontal": Always split horizontally
                                   -- "vertical": Always split vertically
  }
}
```

**Important:** 
- Set `vim.g.gh_opts` **before** the plugin loads (e.g., in your `init.lua`)
- PR support is planned for a future release

### Why Global Variables?

This approach follows [modern Neovim plugin patterns](https://mrcjkb.dev/posts/2023-08-22-setup.html) and provides:
- Faster startup (no `setup()` function call required)
- Simpler configuration
- Compatibility with lazy loading
- Alignment with Neovim 0.12+ conventions

### Accessing Configuration

You can access the resolved configuration at runtime:

```lua
local config = require("gh.config")
print(vim.inspect(config.opts))
```

## Future Plans

- [x] Issue list viewing and editing
- [x] Issue detail viewing and editing  
- [x] Virtual text metadata display with badges
- [ ] Pull request support
- [ ] Issue creation from template
- [ ] Better error messages
- [ ] More tests

## License

VIM License - see [Vim License](https://vimhelp.org/uganda.txt.html#license)
