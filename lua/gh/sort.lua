--- Sorting UI for issue list buffer
--- Provides interactive sorting capabilities with a dedicated pane similar to grug-far.nvim
local M = {}

local buffer = require("gh.buffer")

--- Available sort options
---@class gh.SortOption
---@field name string Display name
---@field key string Sort key identifier
---@field shortcut string Keyboard shortcut
---@field fn fun(collection: gh.IssueCollection, desc: boolean): gh.IssueCollection Sort function

---@type gh.SortOption[]
M.sort_options = {
  { name = "Number", key = "number", shortcut = "n", fn = function(c, d) return c:sort_by_number(d) end },
  { name = "Title", key = "title", shortcut = "t", fn = function(c, d) return c:sort_by_title(d) end },
  { name = "State", key = "state", shortcut = "s", fn = function(c, d) return c:sort_by_state(d) end },
  { name = "Author", key = "author", shortcut = "a", fn = function(c, d) return c:sort_by_author(d) end },
  { name = "Created", key = "created", shortcut = "c", fn = function(c, d) return c:sort_by_created(d) end },
  { name = "Updated", key = "updated", shortcut = "u", fn = function(c, d) return c:sort_by_updated(d) end },
  { name = "Labels", key = "labels", shortcut = "l", fn = function(c, d) return c:sort_by_label_count(d) end },
}

--- Generate content lines for the sort pane
---@param current_sort_key string|nil Current sort key
---@param current_desc boolean Current sort direction
---@return string[] Lines to display
local function generate_sort_pane_lines(current_sort_key, current_desc)
  local lines = {
    "╭─ Sort Issues ─────────────────────────────────────────╮",
    "│                                                       │",
    "│  Press key to sort • Press again to toggle direction │",
    "│  Press <Esc> or q to close                           │",
    "│                                                       │",
    "╰───────────────────────────────────────────────────────╯",
    "",
  }
  
  for _, option in ipairs(M.sort_options) do
    local indicator = ""
    if current_sort_key == option.key then
      indicator = current_desc and " ↓" or " ↑"
    end
    
    local line = string.format("  [%s]  %-12s%s", option.shortcut, option.name, indicator)
    table.insert(lines, line)
  end
  
  table.insert(lines, "")
  table.insert(lines, "  Legend: ↑ ascending • ↓ descending")
  
  return lines
end

--- Apply sorting to the issues buffer
---@param issues_bufnr integer Issue list buffer number
---@param sort_key string Sort key
---@param descending boolean Sort direction
local function apply_sort(issues_bufnr, sort_key, descending)
  -- Get current collection from buffer
  local ok, collection_data = pcall(vim.api.nvim_buf_get_var, issues_bufnr, "gh_issues_collection")
  if not ok or not collection_data then
    vim.notify("No issues loaded in buffer", vim.log.levels.WARN)
    return false
  end
  
  local types = require("gh.types")
  local collection = types.IssueCollection.new(collection_data)
  
  -- Find the sort option
  local option = nil
  for _, opt in ipairs(M.sort_options) do
    if opt.key == sort_key then
      option = opt
      break
    end
  end
  
  if not option then
    vim.notify("Unknown sort key: " .. sort_key, vim.log.levels.ERROR)
    return false
  end
  
  -- Apply sort
  local sorted = option.fn(collection, descending)
  
  -- Update buffer with sorted issues
  local sorted_lines = sorted:format_list()
  buffer.set_lines(issues_bufnr, sorted_lines)
  
  -- Update stored collection and sort state
  vim.api.nvim_buf_set_var(issues_bufnr, "gh_issues_collection", sorted:to_table())
  vim.api.nvim_buf_set_var(issues_bufnr, "gh_sort_key", sort_key)
  vim.api.nvim_buf_set_var(issues_bufnr, "gh_sort_desc", descending)
  
  -- Show notification
  local direction = descending and "descending" or "ascending"
  vim.notify(string.format("Sorted by %s (%s)", option.name, direction), vim.log.levels.INFO)
  
  return true
end

--- Refresh the sort pane display
---@param sort_bufnr integer Sort pane buffer number
---@param issues_bufnr integer Issue list buffer number
local function refresh_sort_pane(sort_bufnr, issues_bufnr)
  -- Get current sort state
  local current_sort_ok, current_sort = pcall(vim.api.nvim_buf_get_var, issues_bufnr, "gh_sort_key")
  local current_desc_ok, current_desc = pcall(vim.api.nvim_buf_get_var, issues_bufnr, "gh_sort_desc")
  
  local sort_key = current_sort_ok and current_sort or nil
  local desc = current_desc_ok and current_desc or false
  
  -- Generate and display lines
  local lines = generate_sort_pane_lines(sort_key, desc)
  buffer.set_lines(sort_bufnr, lines)
end

--- Create and display sorting pane buffer
---@param issues_bufnr integer Issue list buffer number
function M.show_sort_pane(issues_bufnr)
  -- Create or reuse sort pane buffer
  local sort_bufnr = buffer.create_scratch("gh://sort")
  
  -- Set buffer as non-modifiable
  vim.api.nvim_set_option_value("modifiable", false, { buf = sort_bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = sort_bufnr })
  
  -- Display initial content
  refresh_sort_pane(sort_bufnr, issues_bufnr)
  
  -- Set up keymaps for each sort option
  local keymaps = {}
  
  for _, option in ipairs(M.sort_options) do
    keymaps[option.shortcut] = {
      callback = function()
        -- Get current sort state
        local current_sort_ok, current_sort = pcall(vim.api.nvim_buf_get_var, issues_bufnr, "gh_sort_key")
        local current_desc_ok, current_desc = pcall(vim.api.nvim_buf_get_var, issues_bufnr, "gh_sort_desc")
        
        -- Toggle direction if same key
        local descending = false
        if current_sort_ok and current_sort == option.key then
          descending = not (current_desc_ok and current_desc or false)
        end
        
        -- Apply sort
        if apply_sort(issues_bufnr, option.key, descending) then
          -- Refresh the pane to show updated indicators
          refresh_sort_pane(sort_bufnr, issues_bufnr)
        end
      end,
      desc = "Sort by " .. option.name,
    }
  end
  
  -- Add close keymaps
  keymaps["q"] = {
    callback = function()
      vim.cmd("close")
    end,
    desc = "Close sort pane",
  }
  
  keymaps["<Esc>"] = {
    callback = function()
      vim.cmd("close")
    end,
    desc = "Close sort pane",
  }
  
  buffer.set_keymaps(sort_bufnr, keymaps)
  
  -- Open in split (small horizontal split at bottom)
  vim.cmd("botright 15split")
  vim.api.nvim_set_current_buf(sort_bufnr)
  
  -- Set filetype for syntax highlighting
  vim.api.nvim_set_option_value("filetype", "gh-sort", { buf = sort_bufnr })
  
  -- Set up syntax highlighting for the sort pane
  vim.fn.clearmatches()
  vim.fn.matchadd("Comment", [[^╭.*╮$]], 10)
  vim.fn.matchadd("Comment", [[^│.*│$]], 10)
  vim.fn.matchadd("Comment", [[^╰.*╯$]], 10)
  vim.fn.matchadd("Keyword", "\\[.\\]", 10)
  vim.fn.matchadd("Number", [[↑\|↓]], 10)
  vim.fn.matchadd("Comment", [[Legend:.*]], 10)
end

--- Quick sort by a specific key (for direct keybinding)
---@param bufnr integer Buffer number
---@param sort_key string Sort key (e.g., "number", "title", "author")
---@param callback fun(sorted_collection: gh.IssueCollection|nil) Callback with sorted collection
function M.quick_sort(bufnr, sort_key, callback)
  -- Get current collection from buffer
  local ok, collection_data = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_collection")
  if not ok or not collection_data then
    vim.notify("No issues loaded in buffer", vim.log.levels.WARN)
    return
  end
  
  local types = require("gh.types")
  local collection = types.IssueCollection.new(collection_data)
  
  -- Find the sort option
  local option = nil
  for _, opt in ipairs(M.sort_options) do
    if opt.key == sort_key then
      option = opt
      break
    end
  end
  
  if not option then
    vim.notify("Unknown sort key: " .. sort_key, vim.log.levels.ERROR)
    callback(nil)
    return
  end
  
  -- Toggle direction if same sort key
  local current_sort_ok, current_sort = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_sort_key")
  local current_desc_ok, current_desc = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_sort_desc")
  
  local descending = false
  if current_sort_ok and current_sort == sort_key then
    descending = not (current_desc_ok and current_desc or false)
  end
  
  -- Apply sort
  local sorted = option.fn(collection, descending)
  
  -- Store sort state in buffer
  vim.api.nvim_buf_set_var(bufnr, "gh_sort_key", sort_key)
  vim.api.nvim_buf_set_var(bufnr, "gh_sort_desc", descending)
  
  -- Show notification
  local direction = descending and "descending" or "ascending"
  vim.notify(string.format("Sorted by %s (%s)", option.name, direction), vim.log.levels.INFO)
  
  callback(sorted)
end

return M
