--- Filter/Search UI for issue list buffer
--- Provides inline filtering with virtual lines and auto-updating
local M = {}

--- Namespace for virtual text
M.namespace = vim.api.nvim_create_namespace("gh_filter")

--- Line number where filter input is located (1-indexed)
M.FILTER_INPUT_LINE = 1

--- Apply filtering based on input text
---@param bufnr integer Buffer number
---@param input_text string Input from filter line (e.g., "OPEN", "CLOSED", "ALL")
---@return boolean success Whether filtering was applied
function M.apply_filter_from_input(bufnr, input_text)
  -- Clean input
  local filter_value = input_text:gsub("^%s*", ""):gsub("%s*$", ""):upper()
  
  if filter_value == "" then
    filter_value = "ALL"
  end
  
  -- Get current collection from buffer
  local ok, collection_data = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_collection_full")
  if not ok or not collection_data then
    -- Fallback to regular collection if full collection not available
    ok, collection_data = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_collection")
    if not ok or not collection_data then
      return false
    end
    -- Store as full collection for future use
    vim.api.nvim_buf_set_var(bufnr, "gh_issues_collection_full", collection_data)
  end
  
  local types = require("gh.types")
  local full_collection = types.IssueCollection.new(collection_data)
  
  -- Filter based on state
  local filtered_collection
  if filter_value == "OPEN" then
    filtered_collection = full_collection:get_open()
  elseif filter_value == "CLOSED" then
    filtered_collection = full_collection:get_closed()
  else
    -- ALL or anything else shows everything
    filtered_collection = full_collection
  end
  
  -- Generate issue lines
  local issue_lines = {}
  for _, issue in filtered_collection:iter() do
    table.insert(issue_lines, issue:format_list_line())
  end
  
  -- Update buffer: keep only the filter input line, add issues
  local all_lines = { input_text }
  vim.list_extend(all_lines, issue_lines)
  
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, all_lines)
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  
  -- Update stored collection (filtered version for editing)
  vim.api.nvim_buf_set_var(bufnr, "gh_issues_collection", filtered_collection:to_table())
  
  -- Store current filter state
  vim.api.nvim_buf_set_var(bufnr, "gh_filter_state", filter_value)
  
  -- Update virtual text display
  M.update_filter_display(bufnr, filter_value)
  
  -- Show notification
  local count = filtered_collection:count()
  vim.notify(string.format("Showing %d %s issue(s)", count, filter_value), vim.log.levels.INFO)
  
  return true
end

--- Update the filter display with virtual lines
---@param bufnr integer Buffer number
---@param current_filter string|nil Current filter state (OPEN/CLOSED/ALL)
function M.update_filter_display(bufnr, current_filter)
  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)
  
  -- Line 1 (0-indexed = line 0) is the filter input line
  local line_num = 0
  
  -- Get current input text  
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)
  local current_text = lines[1] or ""
  
  -- Show "∴ Status: " label inline before user input
  vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line_num, 0, {
    id = 1, -- Fixed ID for the label
    virt_text = {{ "∴ Status: ", "Title" }},
    virt_text_pos = "inline",
  })
  
  -- Show placeholder when empty
  if current_text == "" or current_text:match("^%s*$") then
    vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line_num, 0, {
      id = 2, -- Fixed ID for placeholder
      virt_text = {{ "OPEN | CLOSED | ALL", "Comment" }},
      virt_text_pos = "overlay",
    })
  end
  
  -- Show horizontal rule below the filter line
  vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line_num, 0, {
    id = 3, -- Fixed ID for separator
    virt_lines = {
      {{ "─────────────────────────────────────────────────────────────", "Comment" }}
    },
  })
  
  -- Add current filter indicator at end of line
  if current_filter and current_filter ~= "ALL" then
    vim.api.nvim_buf_set_extmark(bufnr, M.namespace, line_num, #current_text, {
      virt_text = {{ string.format("  (filtering by: %s)", current_filter), "Comment" }},
      virt_text_pos = "eol",
    })
  end
end

--- Set up auto-filter on text change for filter input line
---@param bufnr integer Buffer number
function M.setup_auto_filter(bufnr)
  -- Create autocmd group
  local group = vim.api.nvim_create_augroup("gh_filter_" .. bufnr, { clear = true })
  
  -- Listen for text changes
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      -- Get cursor position
      local cursor = vim.api.nvim_win_get_cursor(0)
      local line_num = cursor[1]
      
      -- Only process if cursor is on filter input line (line 1)
      if line_num == 1 then
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)
        local input_text = lines[1] or ""
        
        -- Apply filter based on input
        M.apply_filter_from_input(bufnr, input_text)
      end
    end,
  })
  
  -- Update virtual text on cursor move or buffer enter
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      local current_filter_ok, current_filter = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_filter_state")
      local filter_state = current_filter_ok and current_filter or "ALL"
      
      M.update_filter_display(bufnr, filter_state)
    end,
  })
  
  -- Initial display update
  local current_filter_ok, current_filter = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_filter_state")
  local filter_state = current_filter_ok and current_filter or "ALL"
  
  M.update_filter_display(bufnr, filter_state)
end

return M
