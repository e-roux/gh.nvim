--- Reusable UI components for metadata fields
--- Provides a component-based architecture with lifecycle hooks (similar to SolidJS)
local M = {}

--- Component context for managing lifecycle and state
---@class ComponentContext
---@field bufnr integer Buffer number
---@field namespace integer Namespace ID for virtual text
---@field mounted boolean Whether component is mounted
---@field cleanup_fns function[] Cleanup functions to call on unmount
local ComponentContext = {}
ComponentContext.__index = ComponentContext

--- Create a new component context
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@return ComponentContext
function ComponentContext.new(bufnr, namespace)
  local self = setmetatable({
    bufnr = bufnr,
    namespace = namespace,
    mounted = false,
    cleanup_fns = {},
  }, ComponentContext)
  return self
end

--- Register a cleanup function to be called on unmount
---@param fn function Cleanup function
function ComponentContext:on_cleanup(fn)
  table.insert(self.cleanup_fns, fn)
end

--- Mount the component (call onMount hooks)
function ComponentContext:mount()
  self.mounted = true
end

--- Unmount the component (call cleanup functions)
function ComponentContext:unmount()
  for _, fn in ipairs(self.cleanup_fns) do
    pcall(fn)
  end
  self.cleanup_fns = {}
  self.mounted = false
end

--- Helper to create colored badge segments with rounded corners
---@param text string Badge text
---@param hl string|{bg: string, fg: string} Highlight group or color spec
---@return table[] Array of highlight segments
local function create_badge(text, hl)
  local bg, fg
  if type(hl) == "table" then
    bg = hl.bg
    fg = hl.fg
  else
    bg = hl
    fg = nil
  end

  -- Rounded separators (powerline characters)
  local left_sep, right_sep = "", ""

  if type(hl) == "table" and hl.bg and hl.fg then
    -- For custom colors, we need to create temporary highlight groups
    local hl_name = "GhBadge_" .. text:gsub("%W", "_")
    local hl_inv = hl_name .. "Inv"
    vim.api.nvim_set_hl(0, hl_name, { bg = bg, fg = fg })
    vim.api.nvim_set_hl(0, hl_inv, { fg = bg })

    return {
      { left_sep, hl_inv },
      { text, hl_name },
      { right_sep, hl_inv },
    }
  else
    -- Use existing highlight group
    local hl_id = vim.fn.hlID(bg)
    local bg_color = vim.fn.synIDattr(vim.fn.synIDtrans(hl_id), "bg#")
    local fg_color = vim.fn.synIDattr(vim.fn.synIDtrans(hl_id), "fg#")

    if bg_color == "" then
      bg_color = nil
    end
    if fg_color == "" then
      fg_color = nil
    end

    -- Create highlight groups for this badge
    local hl_name = "GhBadge_" .. bg
    local hl_inv = hl_name .. "Inv"

    vim.api.nvim_set_hl(0, hl_name, { bg = bg_color, fg = fg_color })
    if bg_color then
      vim.api.nvim_set_hl(0, hl_inv, { fg = bg_color })
    end

    return {
      { left_sep, bg_color and hl_inv or "Normal" },
      { text, hl_name },
      { right_sep, bg_color and hl_inv or "Normal" },
    }
  end
end

--- Convert hex color to RGB
---@param hex string Hex color like "#ff0000"
---@return number, number, number RGB values
local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

--- Calculate perceived brightness of a color
---@param hex string Hex color like "#ff0000"
---@return number Brightness value 0-255
local function get_brightness(hex)
  local r, g, b = hex_to_rgb(hex)
  return (r * 299 + g * 587 + b * 114) / 1000
end

--- Get appropriate text color (black or white) for a background color
---@param bg_hex string Background color hex
---@return string Foreground color hex
local function get_contrast_color(bg_hex)
  local brightness = get_brightness(bg_hex)
  return brightness > 128 and "#000000" or "#ffffff"
end

--- Format relative time
---@param iso_time string ISO 8601 timestamp
---@return string Relative time string
local function format_relative_time(iso_time)
  if not iso_time then
    return ""
  end

  local year, month, day, hour, min, sec = iso_time:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not year then
    return iso_time:match("^%d%d%d%d%-%d%d%-%d%d") or iso_time
  end

  local time_parts = { year = year, month = month, day = day, hour = hour, min = min, sec = sec }
  local timestamp = os.time(time_parts)
  local now = os.time()
  local diff = now - timestamp

  if diff < 60 then
    return "just now"
  elseif diff < 3600 then
    return math.floor(diff / 60) .. "m ago"
  elseif diff < 86400 then
    return math.floor(diff / 3600) .. "h ago"
  elseif diff < 604800 then
    return math.floor(diff / 86400) .. "d ago"
  elseif diff < 2592000 then
    return math.floor(diff / 604800) .. "w ago"
  elseif diff < 31536000 then
    return math.floor(diff / 2592000) .. "mo ago"
  else
    return math.floor(diff / 31536000) .. "y ago"
  end
end

--- Component: State field
---@class StateComponent
---@field render fun(state: string): {name: string, segments: table[]}
M.State = {
  render = function(state)
    if not state then
      return nil
    end

    local state_upper = state:upper()
    local icon = state_upper == "OPEN" and "●" or state_upper == "CLOSED" and "✓" or "○"
    local hl_group = state_upper == "OPEN" and "DiagnosticInfo" or "DiagnosticHint"

    local segments = {}
    vim.list_extend(segments, create_badge(icon .. " " .. state_upper, hl_group))

    return {
      name = "Status",
      segments = segments,
    }
  end,
}

--- Component: Author field
---@class AuthorComponent
M.Author = {
  render = function(author)
    if not author or not author.login then
      return nil
    end

    local segments = {}
    vim.list_extend(segments, create_badge("  " .. author.login, "Identifier"))

    return {
      name = "Author",
      segments = segments,
    }
  end,
}

--- Component: CreatedAt field
---@class CreatedAtComponent
M.CreatedAt = {
  render = function(created_at)
    if not created_at then
      return nil
    end

    return {
      name = "Created",
      segments = { { format_relative_time(created_at), "Comment" } },
    }
  end,
}

--- Component: UpdatedAt field
---@class UpdatedAtComponent
M.UpdatedAt = {
  render = function(updated_at)
    if not updated_at then
      return nil
    end

    return {
      name = "Updated",
      segments = { { format_relative_time(updated_at), "Comment" } },
    }
  end,
}

--- Component: ClosedAt field
---@class ClosedAtComponent
M.ClosedAt = {
  render = function(closed_at)
    if not closed_at then
      return nil
    end

    return {
      name = "Closed",
      segments = { { format_relative_time(closed_at), "Comment" } },
    }
  end,
}

--- Component: Labels field
---@class LabelsComponent
M.Labels = {
  render = function(labels)
    if not labels or #labels == 0 then
      return nil
    end

    local segments = {}
    for _, label in ipairs(labels) do
      local color = "#" .. (label.color or "888888")
      local fg = get_contrast_color(color)
      vim.list_extend(segments, create_badge(label.name, { bg = color, fg = fg }))
      table.insert(segments, { " ", "Normal" })
    end

    return {
      name = "Labels",
      segments = segments,
    }
  end,
}

--- Component: Assignees field
---@class AssigneesComponent
M.Assignees = {
  render = function(assignees)
    if not assignees or #assignees == 0 then
      return nil
    end

    local segments = {}
    for _, assignee in ipairs(assignees) do
      vim.list_extend(segments, create_badge(assignee.login, "Special"))
      table.insert(segments, { " ", "Normal" })
    end

    return {
      name = "Assignees",
      segments = segments,
    }
  end,
}

--- Component: Milestone field
---@class MilestoneComponent
M.Milestone = {
  render = function(milestone)
    if not milestone or not milestone.title then
      return nil
    end

    local segments = {}
    vim.list_extend(segments, create_badge(milestone.title, "Title"))

    return {
      name = "Milestone",
      segments = segments,
    }
  end,
}

--- Component: URL field
---@class URLComponent
M.URL = {
  render = function(url)
    if not url then
      return nil
    end

    return {
      name = "URL",
      segments = { { url, "Underlined" } },
    }
  end,
}

--- Composite component: Render all metadata fields
---@param item table Issue or PR data
---@return table[] Array of {name: string, segments: table[]}
function M.render_all_metadata(item)
  local props = {}

  -- Render each component
  local state = M.State.render(item.state)
  if state then
    table.insert(props, state)
  end

  local author = M.Author.render(item.author)
  if author then
    table.insert(props, author)
  end

  local created = M.CreatedAt.render(item.createdAt)
  if created then
    table.insert(props, created)
  end

  local updated = M.UpdatedAt.render(item.updatedAt)
  if updated then
    table.insert(props, updated)
  end

  local closed = M.ClosedAt.render(item.closedAt)
  if closed then
    table.insert(props, closed)
  end

  local labels = M.Labels.render(item.labels)
  if labels then
    table.insert(props, labels)
  end

  local assignees = M.Assignees.render(item.assignees)
  if assignees then
    table.insert(props, assignees)
  end

  local milestone = M.Milestone.render(item.milestone)
  if milestone then
    table.insert(props, milestone)
  end

  local url = M.URL.render(item.url)
  if url then
    table.insert(props, url)
  end

  return props
end

--- Render metadata as virtual text lines in a buffer
---@param bufnr integer Buffer number
---@param item table Issue or PR data
---@param opts? {namespace?: integer, line?: integer} Options
function M.render_metadata_to_buffer(bufnr, item, opts)
  opts = opts or {}
  local ns = opts.namespace or vim.api.nvim_create_namespace("gh_metadata")
  local line = opts.line or 1

  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Define bold highlight group for labels
  local comment_fg = vim.fn.synIDattr(vim.fn.hlID("Comment"), "fg")
  local comment_bg = vim.fn.synIDattr(vim.fn.hlID("Comment"), "bg")
  vim.api.nvim_set_hl(0, "GhMetadataLabel", {
    fg = comment_fg ~= "" and comment_fg or nil,
    bg = comment_bg ~= "" and comment_bg or nil,
    bold = true,
    default = true,
  })

  local props = M.render_all_metadata(item)

  if #props == 0 then
    return
  end

  local virt_lines = {}

  -- Build virtual text lines for each property
  for _, prop in ipairs(props) do
    local virt_line = {}

    -- Add label with bold font
    table.insert(virt_line, { prop.name, "GhMetadataLabel" })
    table.insert(virt_line, { ": ", "GhMetadataLabel" })

    -- Add value segments
    for _, segment in ipairs(prop.segments) do
      table.insert(virt_line, segment)
    end

    table.insert(virt_lines, virt_line)
  end

  -- Add blank line for spacing
  table.insert(virt_lines, { { " ", "Normal" } })

  -- Add virtual text after the specified line
  vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
    virt_lines = virt_lines,
    virt_lines_above = false,
  })
end

--- Create a component context for managing lifecycle
---@param bufnr integer Buffer number
---@param namespace? integer Namespace ID (optional)
---@return ComponentContext
function M.create_context(bufnr, namespace)
  namespace = namespace or vim.api.nvim_create_namespace("gh_components")
  return ComponentContext.new(bufnr, namespace)
end

--- Helper to call on_enter for a component by field name
---@param field_name string Field name (e.g., "State", "Author", "Labels")
---@param bufnr integer Buffer number
---@param line integer Line number (1-indexed)
---@param label string Field label text
---@return boolean success Whether the component was found and on_enter was called
function M.call_on_enter(field_name, bufnr, line, label)
  local component = M[field_name]
  if component and component.on_enter then
    component:on_enter(bufnr, line, label)
    return true
  end
  return false
end

--- Get all available component names
---@return string[] Array of component names
function M.get_component_names()
  return {
    "State",
    "Author",
    "CreatedAt",
    "UpdatedAt",
    "ClosedAt",
    "Labels",
    "Assignees",
    "Milestone",
    "URL",
  }
end

--- Set up autocmds for multiple components in a buffer
---@param bufnr integer Buffer number
---@param fields table[] Array of {component_name: string, line: integer, label: string}
function M.setup_field_autocmds(bufnr, fields)
  for _, field in ipairs(fields) do
    local component = M[field.component_name]
    if component and component.setup_autocmds then
      component.setup_autocmds(bufnr, field.line, field.label)
    end
  end
end

return M
