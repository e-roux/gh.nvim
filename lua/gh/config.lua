---@module 'gh'

local M = {}

---Your `gh.nvim` configuration.
---Passed via global variable for simpler UX and faster startup.
---See https://mrcjkb.dev/posts/2023-08-22-setup.html
---@type gh.Opts|nil
vim.g.gh_opts = vim.g.gh_opts

---@class gh.Opts
---
---Data source for GitHub API calls
---  - "api": Use GraphQL API via gh api (fast, recommended)
---  - "json": Use gh CLI with JSON output via plenary jobs
---@field data_source? "api"|"json"
---
---Options for issue detail view behavior
---@field issue_detail? gh.IssueDetailOpts
---
---Options for issue creation
---@field issue_create? gh.IssueCreateOpts
---
---Options for issue list view behavior
---@field issue_list? gh.IssueListOpts

---@class gh.IssueDetailOpts
---
---Reuse existing issue detail window instead of creating new splits.
---When `true`, opening a new issue will replace the current issue detail window.
---When `false`, each issue opens in a new split.
---@field reuse_window? boolean
---
---Split direction for issue detail windows.
---  - "auto": Automatically choose based on window width (vertical if wide, horizontal otherwise)
---  - "horizontal": Always split horizontally
---  - "vertical": Always split vertically
---@field split_direction? "auto"|"horizontal"|"vertical"

---@class gh.IssueCreateOpts
---
---Default assignees for new issues
---@field default_assignees? string[]
---
---Default labels for new issues
---@field default_labels? string[]
---
---Default milestone for new issues
---@field default_milestone? string
---
---Default project for new issues
---@field default_project? string

---@class gh.IssueListOpts
---
---Enable issue deletion with `dd` keymap in issue list
---@field enable_delete? boolean
---
---Require confirmation before deleting issues
---When `true`, prompts for confirmation before deletion
---When `false`, deletes immediately without confirmation
---@field delete_confirmation? boolean

---Default configuration
---@type gh.Opts
local defaults = {
  data_source = "json", -- Use JSON output via gh CLI (reliable)
  issue_detail = {
    reuse_window = true,
    split_direction = "auto", -- Auto-detect based on window width
  },
  issue_create = {
    default_assignees = nil,
    default_labels = nil,
    default_milestone = nil,
    default_project = nil,
  },
  issue_list = {
    enable_delete = true,
    delete_confirmation = true,
  },
}

---Plugin options, lazily merged from `defaults` and `vim.g.gh_opts`.
---@type gh.Opts
M.opts = vim.tbl_deep_extend("force", vim.deepcopy(defaults), vim.g.gh_opts or {})

return M
