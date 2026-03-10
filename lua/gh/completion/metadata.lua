--- Blink.cmp completion source for GitHub metadata fields
--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

--- Get cached contributors/assignees
---@return string[] List of usernames
local function get_cached_users()
  local cache = require("gh.cache")
  local users = {}

  -- Try to get from cache
  local cached = cache.read("contributors")
  if cached then
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
  local cached = cache.read("labels")
  if cached then
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
  local cached = cache.read("milestones")
  if cached then
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

--- Create a new instance of the source
--- @param opts table? Optional configuration
--- @return blink.cmp.Source
function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

--- Check if this source is available in the current context
--- @return boolean
function source.enabled(_self)
  -- Only enable in gh:// buffers
  local bufname = vim.api.nvim_buf_get_name(0)
  return bufname:match("^gh://") ~= nil
end

--- Get completion items
--- @param ctx table Blink.cmp context
--- @param callback function Callback to return items
function source.get_completions(_self, _ctx, callback)
  local line = vim.api.nvim_get_current_line()
  local field_type = detect_field_type(line)

  if not field_type then
    callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
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
      -- Remove @ prefix for the actual username
      local username = user:gsub("^@", "")
      table.insert(items, {
        label = user, -- Keep @ for display
        insertText = username, -- Insert without @
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

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

return source
