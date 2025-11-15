--- Issue buffer management for Oil.nvim-style editing
local M = {}

local buffer = require("gh.buffer")
local cli = require("gh.cli")
local cache = require("gh.cache")
local types = require("gh.types")

--- Valid issue states
local VALID_STATES = {
  OPEN = true,
  CLOSED = true,
}

--- Parse issue list buffer to extract changes
---@param lines string[] Buffer lines
---@param collection gh.IssueCollection Original issue collection
---@return table<integer, {title: string|nil, state: string|nil}>|nil Changes keyed by issue number, or nil if validation failed
---@return string|nil Error message if validation failed
local function parse_issue_list_changes(lines, collection)
  local changes = {}
  local errors = {}
  
  -- Skip header lines (first 2 lines)
  for i = 3, #lines do
    local line = lines[i]
    if line and line ~= "" then
      -- Parse format: "#123 │ OPEN │ Issue title here"
      local number, state, title = line:match("^#(%d+)%s+│%s+(%w+)%s+│%s+(.+)%s*$")
      
      if number then
        number = tonumber(number)
        local original = collection:get(number)
        
        if original then
          local change = {}
          
          -- Check if title changed
          if title ~= original.title then
            change.title = title
          end
          
          -- Check if state changed (normalize to uppercase)
          state = state:upper()
          
          -- Validate state
          if not VALID_STATES[state] then
            table.insert(errors, string.format("Line %d: Invalid state '%s' for issue #%d (must be OPEN or CLOSED)", i, state, number))
          end
          
          local original_state = original.state:upper()
          if state ~= original_state then
            change.state = state:lower()
          end
          
          if next(change) then
            changes[number] = change
          end
        end
      end
    end
  end
  
  -- Return errors if any validation failed
  if #errors > 0 then
    return nil, table.concat(errors, "\n")
  end
  
  return changes, nil
end

--- Format issues as table for buffer display
---@param collection gh.IssueCollection Collection of issues
---@return string[] Formatted lines
local function format_issue_list(collection)
  return collection:format_list()
end

--- Open issue list buffer
---@param repo string|nil Repository (owner/repo) or nil for current repo
function M.open_issue_list(repo)
  local cache_key = repo and ("issues_" .. repo:gsub("/", "_")) or "issues_current"
  
  -- Use cache with fallback to fetch
  cache.get_or_fetch(
    cache_key,
    function(callback)
      cli.list_issues(repo, function(success, issues, error)
        if success then
          callback(issues)
        else
          vim.notify("Failed to fetch issues: " .. (error or "unknown error"), vim.log.levels.ERROR)
          callback(nil)
        end
      end)
    end,
    300, -- 5 minute TTL
    function(issues)
      if not issues then
        return
      end
      
      -- Create collection from raw data
      local collection = types.IssueCollection.new(issues)
      
      -- Create buffer
      local buf_name = repo and ("gh://issues/" .. repo) or "gh://issues"
      local bufnr = buffer.create_scratch(buf_name)
      
      -- Format and display issues
      local lines = format_issue_list(collection)
      buffer.set_lines(bufnr, lines)
      
      -- Store original collection in buffer variable for comparison on write
      vim.api.nvim_buf_set_var(bufnr, "gh_issues_collection", collection:to_table())
      vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
      
      -- Set up write handler
      buffer.on_write(bufnr, function(buf)
        local current_lines = buffer.get_lines(buf)
        local original_data = vim.api.nvim_buf_get_var(buf, "gh_issues_collection")
        local original_collection = types.IssueCollection.new(original_data)
        local target_repo = vim.api.nvim_buf_get_var(buf, "gh_repo")
        if target_repo == "" then
          target_repo = nil
        end
        
        local changes, validation_error = parse_issue_list_changes(current_lines, original_collection)
        
        -- Check for validation errors
        if validation_error then
          vim.notify("Validation failed:\n" .. validation_error, vim.log.levels.ERROR)
          return false
        end
        
        if not next(changes) then
          vim.notify("No changes detected", vim.log.levels.INFO)
          return true
        end
        
        -- Apply changes
        local pending = 0
        local errors = {}
        
        for number, change in pairs(changes) do
          pending = pending + 1
          
          -- Update title if changed
          if change.title then
            cli.update_title(number, change.title, target_repo, function(success, error)
              pending = pending - 1
              if not success then
                table.insert(errors, string.format("#%d title: %s", number, error or "unknown"))
              end
            end)
          end
          
          -- Update state if changed
          if change.state then
            -- Use 'close' or 'reopen' command based on the new state
            local command = change.state == "closed" and "close" or "reopen"
            local args = {"issue", command, tostring(number)}
            if target_repo then
              table.insert(args, "--repo")
              table.insert(args, target_repo)
            end
            
            cli.run(args, function(success, _, error)
              pending = pending - 1
              if not success then
                table.insert(errors, string.format("#%d state: %s", number, error or "unknown"))
              end
            end)
          end
        end
        
        -- Wait for all operations to complete
        vim.wait(5000, function()
          return pending == 0
        end)
        
        if #errors > 0 then
          vim.notify("Errors saving changes:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
          return false
        end
        
        -- Clear cache to force refresh on next open
        cache.clear(cache_key)
        
        return true
      end)
      
      -- Set up keymaps
      buffer.set_keymaps(bufnr, {
        ["<CR>"] = {
          callback = function()
            local line = vim.api.nvim_get_current_line()
            local number = line:match("^#(%d+)")
            if number then
              M.open_issue_detail(tonumber(number), repo)
            end
          end,
          desc = "Open issue detail",
        },
        ["R"] = {
          callback = function()
            cache.clear(cache_key)
            M.open_issue_list(repo)
          end,
          desc = "Refresh issue list",
        },
      })
      
      -- Open buffer
      buffer.open(bufnr)
      
      -- Set filetype for syntax highlighting
      vim.api.nvim_set_option_value("filetype", "gh-issues", { buf = bufnr })
    end
  )
end

--- Parse issue detail buffer
---@param lines string[] Buffer lines
---@return {title: string, body: string} Parsed issue
local function parse_issue_detail(lines)
  local title = ""
  local body_lines = {}
  local in_body = false
  
  for i, line in ipairs(lines) do
    if i == 1 then
      -- First line is title
      title = line:gsub("^#%s*", "")
    elseif i > 2 then
      -- After line 2, everything is body (line 2 is blank separator)
      if not in_body and line == "" then
        in_body = true
      elseif in_body then
        table.insert(body_lines, line)
      end
    end
  end
  
  return {
    title = title,
    body = table.concat(body_lines, "\n"),
  }
end

--- Format issue detail for buffer display
---@param issue table Issue data
---@return string[] Formatted lines
local function format_issue_detail(issue)
  local lines = {
    "# " .. issue.title,
    "",
  }
  
  -- Add body
  if issue.body then
    for line in issue.body:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
  end
  
  return lines
end

--- Add virtual text metadata to issue detail buffer
---@param bufnr integer Buffer number
---@param issue table Issue data
local function add_issue_metadata_virtual_text(bufnr)
  -- Create namespace for virtual text
  local ns_id = vim.api.nvim_create_namespace("gh_issue_metadata")
  
  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  
  -- Get issue from buffer var
  local ok, issue = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_original_issue")
  if not ok or not issue then
    return
  end
  
  local virt_lines = {}
  
  -- State
  if issue.state then
    local state_text = issue.state:upper()
    local state_hl = issue.state == "open" and "DiagnosticInfo" or "DiagnosticHint"
    table.insert(virt_lines, { { "State: ", "Comment" }, { state_text, state_hl } })
  end
  
  -- Author
  if issue.author and issue.author.login then
    table.insert(virt_lines, { { "Author: ", "Comment" }, { "@" .. issue.author.login, "Special" } })
  end
  
  -- Labels
  if issue.labels and #issue.labels > 0 then
    local label_texts = {}
    for _, label in ipairs(issue.labels) do
      table.insert(label_texts, label.name)
    end
    table.insert(virt_lines, { { "Labels: ", "Comment" }, { table.concat(label_texts, ", "), "Tag" } })
  end
  
  -- Assignees
  if issue.assignees and #issue.assignees > 0 then
    local assignee_texts = {}
    for _, assignee in ipairs(issue.assignees) do
      table.insert(assignee_texts, "@" .. assignee.login)
    end
    table.insert(virt_lines, { { "Assignees: ", "Comment" }, { table.concat(assignee_texts, ", "), "Special" } })
  end
  
  -- Dates
  if issue.createdAt then
    local created = issue.createdAt:match("^%d%d%d%d%-%d%d%-%d%d")
    table.insert(virt_lines, { { "Created: ", "Comment" }, { created or issue.createdAt, "Number" } })
  end
  
  if issue.updatedAt then
    local updated = issue.updatedAt:match("^%d%d%d%d%-%d%d%-%d%d")
    table.insert(virt_lines, { { "Updated: ", "Comment" }, { updated or issue.updatedAt, "Number" } })
  end
  
  -- URL
  if issue.url then
    table.insert(virt_lines, { { "URL: ", "Comment" }, { issue.url, "Underlined" } })
  end
  
  -- Add virtual text after line 1 (title line)
  if #virt_lines > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, 1, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  end
end

--- Open issue detail buffer
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo) or nil for current repo
function M.open_issue_detail(number, repo)
  cli.get_issue(number, repo, function(success, issue, error)
    if not success then
      vim.notify("Failed to fetch issue: " .. (error or "unknown error"), vim.log.levels.ERROR)
      return
    end
    
    -- Create buffer
    local buf_name = repo and string.format("gh://issue/%s/%d", repo, number) or string.format("gh://issue/%d", number)
    local bufnr = buffer.create_scratch(buf_name)
    
    -- Format and display issue
    local lines = format_issue_detail(issue)
    buffer.set_lines(bufnr, lines)
    
    -- Store original issue
    vim.api.nvim_buf_set_var(bufnr, "gh_issue_number", number)
    vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
    vim.api.nvim_buf_set_var(bufnr, "gh_original_issue", issue)
    
    -- Add virtual text metadata
    add_issue_metadata_virtual_text(bufnr)
    
    -- Set up write handler
    buffer.on_write(bufnr, function(buf)
      local current_lines = buffer.get_lines(buf)
      local parsed = parse_issue_detail(current_lines)
      local issue_number = vim.api.nvim_buf_get_var(buf, "gh_issue_number")
      local target_repo = vim.api.nvim_buf_get_var(buf, "gh_repo")
      local original = vim.api.nvim_buf_get_var(buf, "gh_original_issue")
      
      if target_repo == "" then
        target_repo = nil
      end
      
      local pending = 0
      local errors = {}
      
      -- Update title if changed
      if parsed.title ~= original.title then
        pending = pending + 1
        cli.update_title(issue_number, parsed.title, target_repo, function(success, err)
          pending = pending - 1
          if not success then
            table.insert(errors, "title: " .. (err or "unknown"))
          end
        end)
      end
      
      -- Update body if changed
      if parsed.body ~= original.body then
        pending = pending + 1
        cli.update_body(issue_number, parsed.body, target_repo, function(success, err)
          pending = pending - 1
          if not success then
            table.insert(errors, "body: " .. (err or "unknown"))
          end
        end)
      end
      
      if pending == 0 then
        vim.notify("No changes detected", vim.log.levels.INFO)
        return true
      end
      
      -- Wait for operations to complete
      vim.wait(5000, function()
        return pending == 0
      end)
      
      if #errors > 0 then
        vim.notify("Errors saving changes:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
        return false
      end
      
      return true
    end)
    
    -- Set up keymaps
    buffer.set_keymaps(bufnr, {
      ["q"] = {
        callback = function()
          vim.cmd("close")
        end,
        desc = "Close issue detail",
      },
      ["gx"] = {
        callback = function()
          local ok, iss = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_original_issue")
          if ok and iss and iss.url then
            vim.ui.open(iss.url)
          end
        end,
        desc = "Open issue in browser",
      },
    })
    
    -- Open in split
    buffer.open_split(bufnr, false)
    
    -- Set filetype
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  end)
end

-- Export for testing
if vim.env.PLENARY_TEST then
  M._test_parse_issue_list_changes = parse_issue_list_changes
end

return M
