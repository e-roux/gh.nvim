--- Shared input field system for filter and metadata inputs
--- Provides common functionality for rendering, updating, and managing input fields
local M = {}

--- Input field definition
---@class InputField
---@field name string Input name (e.g., "state", "assignee")
---@field label string Display label (e.g., "State")
---@field icon string? Nerd font icon
---@field placeholder string? Placeholder text
---@field read_only boolean? Whether the field is read-only
---@field uppercase boolean? Whether to auto-uppercase the value

--- Render state field with colored bullet and highlighting
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param field_name string Field name
---@param line_nr integer Line number (0-indexed)
function M.render_state_decoration(bufnr, namespace, extmark_ids, field_name, line_nr)
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1] or ""
  local state_value = line_content:match("^%s*(.-)%s*$") -- trim whitespace

  -- Remove existing decorations first
  local state_icon_id = field_name .. "_icon"
  local state_hl_id = field_name .. "_hl"
  if extmark_ids[state_icon_id] then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, namespace, extmark_ids[state_icon_id])
    extmark_ids[state_icon_id] = nil
  end
  if extmark_ids[state_hl_id] then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, namespace, extmark_ids[state_hl_id])
    extmark_ids[state_hl_id] = nil
  end

  if state_value == "" then
    return
  end

  local icon = state_value == "OPEN" and "● "
    or state_value == "CLOSED" and "✓ "
    or state_value == "ALL" and "○ "
    or ""
  local hl_group = state_value == "OPEN" and "DiagnosticInfo"
    or state_value == "CLOSED" and "DiagnosticHint"
    or "Comment"

  if icon ~= "" then
    -- Add icon before the state value
    extmark_ids[state_icon_id] = vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr, 0, {
      id = extmark_ids[state_icon_id],
      virt_text = { { icon, hl_group } },
      virt_text_pos = "inline",
      right_gravity = false,
    })

    -- Highlight the state text
    if #line_content > 0 then
      extmark_ids[state_hl_id] = vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr, 0, {
        id = extmark_ids[state_hl_id],
        end_row = line_nr,
        end_col = #line_content,
        hl_group = hl_group,
        hl_mode = "combine",
      })
    end
  end
end

--- Render inline label for a field
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param field InputField Field definition
---@param line_nr integer Line number (0-indexed)
function M.render_inline_label(bufnr, namespace, extmark_ids, field, line_nr)
  local icon = field.icon or ""
  local label_text = icon .. (icon ~= "" and " " or "") .. field.label .. ": "
  local hl_group = field.read_only and "Comment" or "Title"

  extmark_ids[field.name] = vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr, 0, {
    id = extmark_ids[field.name],
    virt_text = { { label_text, "Title" } }, -- Always use Title for labels
    virt_text_pos = "inline",
    right_gravity = false,
  })
end

--- Render placeholder text for empty field
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param field InputField Field definition
---@param line_nr integer Line number (0-indexed)
function M.render_placeholder(bufnr, namespace, extmark_ids, field, line_nr)
  if not field.placeholder then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)
  local content = lines[1] or ""
  local is_empty = content:match("^%s*$") ~= nil

  local placeholder_id = field.name .. "_placeholder"

  if is_empty then
    -- Show placeholder
    local icon = field.icon or ""
    local label_width =
      vim.fn.strdisplaywidth(icon .. (icon ~= "" and " " or "") .. field.label .. ": ")

    extmark_ids[placeholder_id] = vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr, 0, {
      id = extmark_ids[placeholder_id],
      virt_text = { { field.placeholder, "Comment" } },
      virt_text_pos = "overlay",
      virt_text_win_col = label_width,
    })
  else
    -- Remove placeholder
    if extmark_ids[placeholder_id] then
      pcall(vim.api.nvim_buf_del_extmark, bufnr, namespace, extmark_ids[placeholder_id])
      extmark_ids[placeholder_id] = nil
    end
  end
end

--- Highlight read-only field
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param field InputField Field definition
---@param line_nr integer Line number (0-indexed)
function M.render_readonly_highlight(bufnr, namespace, extmark_ids, field, line_nr)
  if not field.read_only then
    return
  end

  local line_content = vim.api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1] or ""
  local line_len = #line_content

  local readonly_id = field.name .. "_readonly"

  if line_len > 0 then
    extmark_ids[readonly_id] = vim.api.nvim_buf_set_extmark(bufnr, namespace, line_nr, 0, {
      id = extmark_ids[readonly_id],
      end_row = line_nr,
      end_col = line_len,
      hl_group = "Comment",
      hl_mode = "combine",
    })
  end
end

--- Clear a field value (set to empty string, don't delete line)
---@param bufnr integer Buffer number
---@param line_nr integer Line number (1-indexed)
function M.clear_field(bufnr, line_nr)
  vim.api.nvim_buf_set_lines(bufnr, line_nr - 1, line_nr, false, { "" })
end

--- Uppercase a field value
---@param bufnr integer Buffer number
---@param line_nr integer Line number (1-indexed)
function M.uppercase_field(bufnr, line_nr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)
  local content = lines[1] or ""
  if content ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, line_nr - 1, line_nr, false, { content:upper() })
  end
end

--- Get field value
---@param bufnr integer Buffer number
---@param line_nr integer Line number (1-indexed)
---@return string
function M.get_field_value(bufnr, line_nr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)
  return vim.trim(lines[1] or "")
end

--- Setup common keymaps for input fields
---@param bufnr integer Buffer number
---@param namespace integer Namespace ID
---@param extmark_ids table<string, integer> Extmark IDs
---@param fields InputField[] List of fields
---@param update_callback function Callback to update display
function M.setup_keymaps(bufnr, namespace, extmark_ids, fields, update_callback)
  -- Clear field with dd (set to empty, don't delete line)
  vim.keymap.set("n", "dd", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_num = cursor[1]

    -- Check if we're on an input field line
    for _, field in ipairs(fields) do
      if field.line and field.line == line_num then
        M.clear_field(bufnr, line_num)
        if update_callback then
          update_callback()
        end
        return
      end
    end

    -- Not on an input field line, use default dd behavior
    vim.cmd("normal! dd")
  end, {
    buffer = bufnr,
    desc = "Clear input field (or delete line)",
  })

  -- Enter key: validate and exit insert mode, don't add newline
  vim.keymap.set("i", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_num = cursor[1]

    -- Check if we're on an input field line
    for _, field in ipairs(fields) do
      if field.line and field.line == line_num then
        -- Uppercase if needed
        if field.uppercase then
          M.uppercase_field(bufnr, line_num)
        end

        -- Exit insert mode and update display
        vim.cmd("stopinsert")
        if update_callback then
          vim.schedule(function()
            update_callback()
          end)
        end

        -- Return empty string to prevent newline
        return ""
      end
    end

    -- Not on an input field line, use default Enter behavior
    return "<CR>"
  end, {
    buffer = bufnr,
    expr = true,
    desc = "Apply input (no newline in input fields)",
  })
end

return M
