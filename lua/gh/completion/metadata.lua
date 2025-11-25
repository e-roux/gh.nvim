--- Blink.cmp completion source for GitHub metadata fields
local M = {}

--- Get cached contributors/assignees
---@return string[] List of usernames
local function get_cached_users()
  local cache = require("gh.cache")
  local users = {}

  -- Try to get from cache
  local ok, cached = pcall(cache.get, "contributors")
  if ok and cached then
    for _, user in ipairs(cached) do
      if user.login then
        table.insert(users, "@" .. user.login)
      end
    end
  end

  return users
end

--- Get cached labels
---@return string[] List of label names
local function get_cached_labels()
  local cache = require("gh.cache")
  local labels = {}

  -- Try to get from cache
  local ok, cached = pcall(cache.get, "labels")
  if ok and cached then
    for _, label in ipairs(cached) do
      if label.name then
        table.insert(labels, label.name)
      end
    end
  end

  return labels
end

--- Get cached milestones
---@return string[] List of milestone titles
local function get_cached_milestones()
  local cache = require("gh.cache")
  local milestones = {}

  -- Try to get from cache
  local ok, cached = pcall(cache.get, "milestones")
  if ok and cached then
    for _, milestone in ipairs(cached) do
      if milestone.title then
        table.insert(milestones, milestone.title)
      end
    end
  end

  return milestones
end

--- Detect which metadata field we're on
---@param line string Current line content
---@return string? field_type Type of field (state, assignees, labels, milestone)
local function detect_field_type(line)
  if line:match("^󰊢 State:") then
    return "state"
  elseif line:match("^󰀉 Assignees:") then
    return "assignees"
  elseif line:match("^󰀉 Author:") then
    return "author"
  elseif line:match("^󰓹 Labels:") then
    return "labels"
  elseif line:match("^󰄮 Milestone:") then
    return "milestone"
  end
  return nil
end

--- Blink.cmp source
M.source = {
  name = "gh_metadata",
  priority = 100,

  --- Check if this source is available in the current context
  ---@param ctx table Blink.cmp context
  ---@return boolean
  enabled = function(ctx)
    -- Only enable in gh:// buffers
    local bufname = vim.api.nvim_buf_get_name(ctx.bufnr)
    return bufname:match("^gh://")
  end,

  --- Get completion items
  ---@param ctx table Blink.cmp context
  ---@param callback function Callback to return items
  get_completions = function(ctx, callback)
    local line = vim.api.nvim_get_current_line()
    local field_type = detect_field_type(line)

    if not field_type then
      callback({ items = {} })
      return
    end

    local items = {}

    if field_type == "state" then
      items = {
        { label = "OPEN", kind = vim.lsp.protocol.CompletionItemKind.Enum },
        { label = "CLOSED", kind = vim.lsp.protocol.CompletionItemKind.Enum },
      }
    elseif field_type == "assignees" or field_type == "author" then
      local users = get_cached_users()
      for _, user in ipairs(users) do
        table.insert(items, {
          label = user,
          kind = vim.lsp.protocol.CompletionItemKind.User,
        })
      end
    elseif field_type == "labels" then
      local labels = get_cached_labels()
      for _, label in ipairs(labels) do
        table.insert(items, {
          label = label,
          kind = vim.lsp.protocol.CompletionItemKind.Keyword,
        })
      end
    elseif field_type == "milestone" then
      local milestones = get_cached_milestones()
      for _, milestone in ipairs(milestones) do
        table.insert(items, {
          label = milestone,
          kind = vim.lsp.protocol.CompletionItemKind.Value,
        })
      end
    end

    callback({ items = items })
  end,
}

--- Setup blink.cmp integration
function M.setup()
  local ok, blink = pcall(require, "blink.cmp")
  if not ok then
    return
  end

  -- Register our source
  if blink.register_source then
    blink.register_source(M.source)
  end
end

return M
