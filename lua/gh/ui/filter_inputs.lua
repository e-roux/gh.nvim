--- Filter inputs system inspired by grug-far.nvim
--- Simple extmark-based approach for input fields
local M = {}
local input_field = require("gh.ui.input_field")

--- Filter input definition
---@class FilterInput
---@field name string Input name (e.g., "state", "assignee")
---@field label string Display label (e.g., "◉ State")
---@field placeholder string Placeholder text
---@field keymap string Keymap shortcut (e.g., "s", "a")
---@field line integer Suggested line number (can shift)

--- Filter inputs configuration (grug-far style with icons)
M.inputs = {
  {
    name = "state",
    label = "State",
    icon = "󰊢",
    placeholder = "OPEN | CLOSED | ALL",
    keymap = "s",
    line = 2,
    uppercase = true,
  },
  {
    name = "assignee",
    label = "Assignee",
    icon = "󰀉",
    placeholder = "@username or leave empty",
    keymap = "a",
    line = 3,
  },
  {
    name = "author",
    label = "Author",
    icon = "󰀉",
    placeholder = "@username or leave empty",
    keymap = "u",
    line = 4,
  },
  {
    name = "label",
    label = "Label",
    icon = "󰓹",
    placeholder = "bug, enhancement, ...",
    keymap = "l",
    line = 5,
  },
  {
    name = "mention",
    label = "Mention",
    icon = "󰀉",
    placeholder = "@username or leave empty",
    keymap = "m",
    line = 6,
  },
  {
    name = "milestone",
    label = "Milestone",
    icon = "󰄮",
    placeholder = "milestone name or leave empty",
    keymap = "t",
    line = 7,
  },
  {
    name = "search",
    label = "Search",
    icon = "󰱼",
    placeholder = "search query or leave empty",
    keymap = "/",
    line = 8,
  },
}

--- Get position of input within buffer
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param name string Input name
---@return integer? start_row, integer? end_row
local function get_input_pos(bufnr, namespace, extmark_ids, name)
  local input_idx = nil
  for i, input in ipairs(M.inputs) do
    if input.name == name then
      input_idx = i
      break
    end
  end

  if not input_idx then
    return nil, nil
  end

  local next_input = M.inputs[input_idx + 1]
  local next_name = next_input and next_input.name or "results_header"

  local extmark_id = extmark_ids[name]
  local next_extmark_id = extmark_ids[next_name]

  if not (extmark_id and next_extmark_id) then
    return nil, nil
  end

  local start_row = unpack(vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, extmark_id, {}))
  local end_row = unpack(vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, next_extmark_id, {}))

  return start_row, end_row
end

--- Get input value for given input name
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param name string Input name
---@return string
function M.get_value(bufnr, namespace, extmark_ids, name)
  local start_row, end_row = get_input_pos(bufnr, namespace, extmark_ids, name)

  if not (start_row and end_row) then
    return ""
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
  local value = table.concat(lines, "\n")
  return vim.trim(value)
end

--- Get all input values
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@return table<string, string>
function M.get_values(bufnr, namespace, extmark_ids)
  local values = {}
  for _, input in ipairs(M.inputs) do
    values[input.name] = M.get_value(bufnr, namespace, extmark_ids, input.name)
  end
  return values
end

--- Render all filter inputs
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
function M.render(bufnr, namespace, extmark_ids)
  for _, input in ipairs(M.inputs) do
    local line_nr = input.line

    -- Ensure the line exists
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_nr > line_count then
      vim.api.nvim_buf_set_lines(
        bufnr,
        line_count,
        line_nr,
        false,
        vim.fn["repeat"]({ "" }, line_nr - line_count)
      )
    end

    -- Get current content
    local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)
    local content = lines[1] or ""
    local is_empty = content:match("^%s*$") ~= nil

    -- Set extmark for input position with icon (grug-far style - inline label)
    local icon = input.icon or ""
    local label_text = icon .. " " .. input.label .. ": "

    extmark_ids[input.name] = vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr - 1, 0, {
      id = extmark_ids[input.name],
      end_row = line_nr - 1,
      end_col = 0,
      virt_text = { { label_text, "Title" } },
      virt_text_pos = "inline",
      right_gravity = false,
    })

    -- Add placeholder if empty (only placeholder text, positioned after the label)
    local placeholder_name = input.name .. "_placeholder"
    if is_empty then
      -- Calculate the column position after the label
      local label_width = vim.fn.strdisplaywidth(label_text)
      extmark_ids[placeholder_name] =
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr - 1, 0, {
          id = extmark_ids[placeholder_name],
          virt_text = { { input.placeholder, "Comment" } },
          virt_text_pos = "overlay",
          virt_text_win_col = label_width,
        })
    elseif extmark_ids[placeholder_name] then
      vim.api.nvim_buf_del_extmark(bufnr, namespace, extmark_ids[placeholder_name])
      extmark_ids[placeholder_name] = nil
    end
  end

  -- Add results header marker (grug-far style)
  local last_input = M.inputs[#M.inputs]
  local header_line = last_input.line + 1

  -- Get issue count if available
  local issue_count_text = ""
  local ok, collection_data = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_collection")
  if ok and collection_data and collection_data.items then
    local count = #collection_data.items
    issue_count_text = string.format(" %d issue%s ", count, count == 1 and "" or "s")
  end

  -- Build header with separator and stats (grug-far style)
  local virt_lines = {
    { { "", "Normal" } }, -- blank line above
    {
      {
        "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
        "Comment",
      },
    },
  }

  -- Add issue count if available
  if issue_count_text ~= "" then
    table.insert(virt_lines, { { issue_count_text, "String" } })
  end

  -- Blank line after
  table.insert(virt_lines, { { "", "Normal" } })

  extmark_ids.results_header = vim.api.nvim_buf_set_extmark(bufnr, namespace, header_line - 1, 0, {
    id = extmark_ids.results_header,
    virt_lines_above = true,
    virt_lines = virt_lines,
    virt_lines_leftcol = true,
  })
end

--- Update display (refresh placeholders and state bullets)
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
function M.update_display(bufnr, namespace, extmark_ids)
  for _, input in ipairs(M.inputs) do
    local start_row = get_input_pos(bufnr, namespace, extmark_ids, input.name)
    if not start_row then
      goto continue
    end

    -- Update placeholder
    input_field.render_placeholder(bufnr, namespace, extmark_ids, input, start_row)

    -- Special handling for state field: add colored bullet
    if input.name == "state" then
      input_field.render_state_decoration(bufnr, namespace, extmark_ids, input.name, start_row)
    end

    ::continue::
  end
end

--- Jump to input field
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param name string Input name
function M.jump_to_input(bufnr, namespace, extmark_ids, name)
  local start_row = get_input_pos(bufnr, namespace, extmark_ids, name)
  if start_row then
    vim.api.nvim_win_set_cursor(0, { start_row + 1, 0 })
  end
end

--- Setup keymaps for filter inputs
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
function M.setup_keymaps(bufnr, namespace, extmark_ids)
  -- Jump to input shortcuts
  for _, input in ipairs(M.inputs) do
    vim.keymap.set("n", input.keymap, function()
      M.jump_to_input(bufnr, namespace, extmark_ids, input.name)
    end, {
      buffer = bufnr,
      desc = "Jump to " .. input.label .. " filter",
    })
  end

  -- Setup common keymaps (dd, Enter) using shared module
  input_field.setup_keymaps(bufnr, namespace, extmark_ids, M.inputs, function()
    M.update_display(bufnr, namespace, extmark_ids)
  end)
end

return M
