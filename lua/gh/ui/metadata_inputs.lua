--- Metadata inputs system for issue detail view (grug-far style)
--- Provides inline labels with icons for issue metadata fields
local M = {}
local input_field = require("gh.ui.input_field")

--- Metadata input definition
---@class MetadataInput
---@field name string Input name (e.g., "state", "assignee")
---@field label string Display label (e.g., "State")
---@field icon string Nerd font icon
---@field line integer Line number in buffer
---@field read_only boolean Whether the field is read-only

--- Metadata inputs configuration (grug-far style with icons)
--- Note: line numbers are relative offsets, actual line will be calculated
M.inputs = {
  { name = "state", label = "State", icon = "󰊢", offset = 0, read_only = false },
  { name = "author", label = "Author", icon = "󰀉", offset = 1, read_only = true },
  { name = "created_at", label = "Created", icon = "󰃰", offset = 2, read_only = true },
  { name = "updated_at", label = "Updated", icon = "󰃰", offset = 3, read_only = true },
  { name = "closed_at", label = "Closed", icon = "󰃰", offset = 4, read_only = true },
  { name = "labels", label = "Labels", icon = "󰓹", offset = 5, read_only = false },
  { name = "assignees", label = "Assignees", icon = "󰀉", offset = 6, read_only = false },
  { name = "milestone", label = "Milestone", icon = "󰄮", offset = 7, read_only = false },
  { name = "url", label = "URL", icon = "󰌷", offset = 8, read_only = true },
}

--- Render metadata inputs with values (all as buffer lines with inline labels)
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param values table<string, string> Metadata values
---@param start_line integer Line number to start rendering (1-indexed, typically line after title)
function M.render(bufnr, namespace, extmark_ids, values, start_line)
  start_line = start_line or 1

  -- Build all metadata lines as buffer lines (both read-only and editable)
  local lines_to_insert = {}
  local metadata_fields = {}

  for _, input in ipairs(M.inputs) do
    local value = values[input.name] or ""
    local icon = input.icon or ""
    local label_text = icon .. " " .. input.label .. ": "

    -- Add as buffer line
    table.insert(lines_to_insert, value)
    table.insert(metadata_fields, {
      input = input,
      label_text = label_text,
      line_offset = #lines_to_insert - 1,
    })
  end

  -- Insert all metadata lines, pushing body content down
  vim.api.nvim_buf_set_lines(bufnr, start_line, start_line, false, lines_to_insert)

  -- Add inline labels for all fields
  for _, field in ipairs(metadata_fields) do
    local line_nr = start_line + field.line_offset

    -- Render inline label using shared module
    input_field.render_inline_label(bufnr, namespace, extmark_ids, field.input, line_nr)

    -- Special handling for State field: add colored bullet
    if field.input.name == "state" then
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, field.input.name, line_nr)
    end

    -- Highlight read-only lines
    input_field.render_readonly_highlight(bufnr, namespace, extmark_ids, field.input, line_nr)
  end

  -- Add blank line before metadata block (after title)
  extmark_ids.blank_before = vim.api.nvim_buf_set_extmark(bufnr, namespace, start_line - 1, 0, {
    id = extmark_ids.blank_before,
    virt_lines = { { { "", "Normal" } } },
    virt_lines_above = false,
    virt_lines_leftcol = true,
  })

  -- Add separator line with blank line after all metadata
  local separator_line = start_line + #lines_to_insert
  local separator_virt_lines = {
    { { "", "Normal" } }, -- blank line before separator
    {
      {
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "Comment",
      },
    },
  }

  extmark_ids.separator = vim.api.nvim_buf_set_extmark(bufnr, namespace, separator_line, 0, {
    id = extmark_ids.separator,
    virt_lines = separator_virt_lines,
    virt_lines_above = true,
    virt_lines_leftcol = true,
  })
end

--- Extract metadata values from issue data
---@param issue table Issue data
---@return table<string, string> Metadata values
function M.extract_values(issue)
  local values = {}

  -- State (just the text, icon will be added as virtual text)
  if issue.state then
    values.state = issue.state:upper()
  end

  -- Author
  if issue.author and issue.author.login then
    values.author = "@" .. issue.author.login
  end

  -- Timestamps
  if issue.createdAt then
    values.created_at = M.format_relative_time(issue.createdAt)
  end
  if issue.updatedAt then
    values.updated_at = M.format_relative_time(issue.updatedAt)
  end
  if issue.closedAt then
    values.closed_at = M.format_relative_time(issue.closedAt)
  end

  -- Labels
  if issue.labels and #issue.labels > 0 then
    local label_names = {}
    for _, label in ipairs(issue.labels) do
      table.insert(label_names, label.name)
    end
    values.labels = table.concat(label_names, ", ")
  end

  -- Assignees
  if issue.assignees and #issue.assignees > 0 then
    local assignee_names = {}
    for _, assignee in ipairs(issue.assignees) do
      table.insert(assignee_names, "@" .. assignee.login)
    end
    values.assignees = table.concat(assignee_names, ", ")
  end

  -- Milestone
  if issue.milestone and issue.milestone.title then
    values.milestone = issue.milestone.title
  end

  -- URL
  if issue.url then
    values.url = issue.url
  end

  return values
end

--- Format relative time (e.g., "2h ago", "3d ago")
---@param timestamp string ISO 8601 timestamp
---@return string Relative time string
function M.format_relative_time(timestamp)
  local now = os.time()
  local time = vim.fn.strptime("%Y-%m-%dT%H:%M:%SZ", timestamp)
  if not time or time == 0 then
    return timestamp
  end

  local diff = now - time

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

return M
