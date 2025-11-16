--- Issue buffer management for Oil.nvim-style editing
local M = {}

local buffer = require("gh.buffer")
local cli = require("gh.cli")
local cache = require("gh.cache")
local types = require("gh.types")

--- Namespace for selected issue highlighting
local selected_ns = vim.api.nvim_create_namespace("gh_selected_issue")

--- Valid issue states
local VALID_STATES = {
  OPEN = true,
  CLOSED = true,
}

--- Set up syntax highlighting for issue list
---@param bufnr integer Buffer number
local function setup_issue_list_highlights(bufnr)
  -- Define highlight groups if they don't exist
  vim.api.nvim_set_hl(0, "GhIssueNumber", { link = "Number", default = true })
  vim.api.nvim_set_hl(0, "GhIssueStateOpen", { link = "DiagnosticOk", default = true })
  vim.api.nvim_set_hl(0, "GhIssueStateClosed", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "GhIssueTitle", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "GhIssueSeparator", { link = "Comment", default = true })
  
  -- Clear any existing matches
  vim.fn.clearmatches()
  
  -- Apply syntax highlighting patterns
  -- Match issue numbers: #123
  vim.fn.matchadd("GhIssueNumber", [[^#\d\+]], 10, -1, { window = 0 })
  
  -- Match OPEN state
  vim.fn.matchadd("GhIssueStateOpen", [[│\s\+OPEN\s\+│]], 10, -1, { window = 0 })
  
  -- Match CLOSED state
  vim.fn.matchadd("GhIssueStateClosed", [[│\s\+CLOSED\s\+│]], 10, -1, { window = 0 })
  
  -- Match separators │
  vim.fn.matchadd("GhIssueSeparator", [[│]], 10, -1, { window = 0 })
end

--- Highlight the selected issue line in bold
---@param bufnr integer Buffer number
---@param line_num integer Line number (1-indexed) to highlight
local function highlight_selected_issue(bufnr, line_num)
  -- Define bold highlight group if it doesn't exist
  vim.api.nvim_set_hl(0, "GhIssueSelected", { bold = true, default = true })
  
  -- Clear previous selection highlighting
  vim.api.nvim_buf_clear_namespace(bufnr, selected_ns, 0, -1)
  
  -- Add bold highlight to the entire line
  if line_num > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, selected_ns, line_num - 1, 0, {
      end_row = line_num,
      hl_group = "GhIssueSelected",
      hl_eol = true,
    })
  end
end

--- Parse issue list buffer to extract changes
---@param lines string[] Buffer lines
---@param collection gh.IssueCollection Original issue collection
---@return table<integer, {title: string|nil, state: string|nil}>|nil Changes keyed by issue number, or nil if validation failed
---@return string|nil Error message if validation failed
local function parse_issue_list_changes(lines, collection)
  local changes = {}
  local errors = {}
  
  -- Skip filter lines (lines 1-7), start from line 8 where issues begin
  local filter_ui = require("gh.filter")
  for i = filter_ui.FIRST_ISSUE_LINE, #lines do
    local line = lines[i]
    if line and line ~= "" then
      -- Parse format: "#123 │ Issue title here" (state removed, now in filter)
      local number, title = line:match("^#0*(%d+)%s+│%s+(.+)%s*$")
      
      if number then
        number = tonumber(number)
        local original = collection:get(number)
        
        if original then
          local change = {}
          
          -- Check if title changed
          if title ~= original.title then
            change.title = title
          end
          
          -- Note: State is now managed via filter lines, not in issue lines
          -- No state validation needed here
          
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
---@param filter_context table|nil Optional filter context to pre-populate filter lines
---@return string[] Formatted lines
local function format_issue_list(collection, filter_context)
  return collection:format_list(filter_context)
end

--- Open issue list buffer
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param opts table|nil Options: { limit: number, append: boolean, existing_bufnr: number, state: string }
function M.open_issue_list(repo, opts)
  opts = opts or {}
  
  -- Calculate default limit based on window height
  -- Subtract 2 for header lines, and a few more for comfort
  local default_limit = math.max(10, vim.api.nvim_win_get_height(0) - 4)
  
  local limit = opts.limit or default_limit
  local append = opts.append or false
  local existing_bufnr = opts.existing_bufnr
  local state = opts.state or "open"  -- Default to "open" to mirror gh CLI
  
  -- Include state in cache key
  local cache_key = string.format("issues_%s_%s", 
    repo and repo:gsub("/", "_") or "current",
    state
  )
  
  -- For appending, we skip cache and always fetch fresh data
  if append then
    -- Get existing collection to determine how many we already have
    local bufnr = existing_bufnr or vim.api.nvim_get_current_buf()
    local ok, existing_data = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_collection")
    if not ok then
      vim.notify("Cannot append: buffer not initialized", vim.log.levels.ERROR)
      return
    end
    
    -- Get existing filter context to maintain consistency
    local ok_filter, existing_filter = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_filter_context")
    local filter_context = ok_filter and existing_filter or { state = state }
    
    local currently_loaded = #existing_data
    local new_limit = currently_loaded + limit  -- Fetch more than we have
    
    vim.notify(string.format("Loading issues %d-%d...", currently_loaded + 1, new_limit), vim.log.levels.INFO)
    
    -- Build CLI options from filter context
    local cli_opts = vim.tbl_extend("force", filter_context, { limit = new_limit })
    
    cli.list_issues(repo, cli_opts, function(success, all_issues, error)
      if not success then
        vim.notify("Failed to fetch more issues: " .. (error or "unknown error"), vim.log.levels.ERROR)
        return
      end
      
      if not all_issues or #all_issues == 0 then
        vim.notify("No issues found", vim.log.levels.INFO)
        return
      end
      
      -- Check if we got more issues than before
      if #all_issues <= currently_loaded then
        -- No more issues available - mark as exhausted
        vim.api.nvim_buf_set_var(bufnr, "gh_issues_exhausted", true)
        -- Don't show notification for auto-load, only for manual M press
        return
      end
      
      -- Update buffer with all issues
      local collection = types.IssueCollection.new(all_issues)
      -- Use filter_context from outer scope (retrieved from buffer or defaulted)
      local lines = format_issue_list(collection, filter_context)
      buffer.set_lines(bufnr, lines)
      
      -- Update stored collection
      vim.api.nvim_buf_set_var(bufnr, "gh_issues_collection", collection:to_table())
      vim.api.nvim_buf_set_var(bufnr, "gh_issues_loaded", #all_issues)
      
      local added = #all_issues - currently_loaded
      -- Only show notification if it was manually triggered (via M key)
      if not vim.api.nvim_buf_get_var(bufnr, "gh_loading") then
        vim.notify(string.format("Loaded %d more issues (%d total)", added, #all_issues), vim.log.levels.INFO)
      end
    end)
    return
  end
  
  -- Use cache with fallback to fetch
  cache.get_or_fetch(
    cache_key,
    function(callback)
      cli.list_issues(repo, { limit = limit, state = state }, function(success, issues, error)
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
      -- Build filter context from opts to pre-populate filter lines
      local filter_context = {
        state = state,
        assignee = opts.assignee,
        author = opts.author,
        label = opts.label,
        mention = opts.mention,
        milestone = opts.milestone,
        search = opts.search,
      }
      local lines = format_issue_list(collection, filter_context)
      buffer.set_lines(bufnr, lines)
      
      -- Store original collection in buffer variable for comparison on write
      vim.api.nvim_buf_set_var(bufnr, "gh_issues_collection", collection:to_table())
      vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
      vim.api.nvim_buf_set_var(bufnr, "gh_issues_loaded", #issues)
      vim.api.nvim_buf_set_var(bufnr, "gh_issues_state", state)
      vim.api.nvim_buf_set_var(bufnr, "gh_filter_context", filter_context)
      
      -- Mark buffer as initializing to prevent autocmds from triggering filter updates
      vim.api.nvim_buf_set_var(bufnr, "gh_initializing", true)
      
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
            local line_num = vim.api.nvim_win_get_cursor(0)[1]
            local number = line:match("^#(%d+)")
            if number then
              -- Highlight the selected issue line in bold
              highlight_selected_issue(bufnr, line_num)
              M.open_issue_detail(tonumber(number), repo)
            end
          end,
          desc = "Open issue detail",
        },
        ["R"] = {
          callback = function()
            cache.clear(cache_key)
            M.open_issue_list(repo, { state = state })
          end,
          desc = "Refresh issue list",
        },
        ["M"] = {
          callback = function()
            -- Calculate increment based on window height (same as initial load)
            local increment = math.max(10, vim.api.nvim_win_get_height(0) - 4)
            M.open_issue_list(repo, { 
              limit = increment, 
              append = true,
              existing_bufnr = bufnr,
              state = state,
            })
          end,
          desc = "Load more issues (window height)",
        },
      })
      
      -- Set up inline filter UI with auto-update
      local filter_ui = require("gh.filter")
      filter_ui.setup_auto_filter(bufnr)
      
      -- Set up auto-load on scroll to bottom
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = function()
          -- Check if we've already loaded all available issues
          local ok, exhausted = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_exhausted")
          if ok and exhausted then
            return
          end
          
          -- Check if we're near the bottom of the buffer
          local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
          local total_lines = vim.api.nvim_buf_line_count(bufnr)
          local window_height = vim.api.nvim_win_get_height(0)
          
          -- If cursor is within 3 lines of the bottom, auto-load more
          if cursor_line >= total_lines - 3 then
            -- Check if we're already loading
            local ok_loading, loading = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_loading")
            if ok_loading and loading then
              return
            end
            
            -- Set loading flag to prevent duplicate fetches
            vim.api.nvim_buf_set_var(bufnr, "gh_loading", true)
            
            -- Calculate increment based on window height
            local increment = math.max(10, window_height - 4)
            
            M.open_issue_list(repo, { 
              limit = increment, 
              append = true,
              existing_bufnr = bufnr,
              state = state,
            })
            
            -- Clear loading flag after a short delay
            vim.defer_fn(function()
              pcall(vim.api.nvim_buf_set_var, bufnr, "gh_loading", false)
            end, 1000)
          end
        end,
      })
      
      -- Open buffer
      buffer.open(bufnr)
      
      -- Set up syntax highlighting
      setup_issue_list_highlights(bufnr)
      
      -- Set filetype for syntax highlighting
      vim.api.nvim_set_option_value("filetype", "gh-issues", { buf = bufnr })
      
      -- Mark initialization as complete after everything is set up
      vim.schedule(function()
        vim.api.nvim_buf_set_var(bufnr, "gh_initializing", false)
      end)
    end
  )
end

--- Parse issue detail buffer
---@param lines string[] Buffer lines
---@return {title: string, body: string} Parsed issue
local function parse_issue_detail(lines)
  local title = ""
  local body_lines = {}
  
  for i, line in ipairs(lines) do
    if i == 1 then
      -- First line is title
      title = line:gsub("^#%s*", "")
    elseif i > 2 then
      -- Line 2 is the blank separator, everything after is body
      table.insert(body_lines, line)
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
    -- Split by newline, preserving empty lines
    for line in (issue.body .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
  end
  
  return lines
end

--- Add virtual text metadata to issue detail buffer
---@param bufnr integer Buffer number
---@param issue table Issue data
local function add_issue_metadata_virtual_text(bufnr)
  -- Get issue from buffer var
  local ok, issue = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_original_issue")
  if not ok or not issue then
    return
  end
  
  -- Use the new render module for Snacks-style rendering
  local render = require("gh.render")
  render.render_metadata(bufnr, issue)
end

--- Open issue detail buffer for editing
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
    
    -- Open in split with config options
    local config = require("gh.config")
    buffer.open_smart(bufnr, {
      reuse_window = config.opts.issue_detail.reuse_window,
      split_direction = config.opts.issue_detail.split_direction,
    })
    
    -- Set filetype
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  end)
end

--- Set up autocmds for gh:// buffers
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("GhNvim", { clear = true })
  
  -- Suppress errors for gh:// buffers on BufEnter
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "gh://*",
    callback = function()
      -- Mark as valid buffer to suppress errors from other plugins
      vim.bo.buftype = "acwrite"
      vim.b.is_gh_buffer = true
      return true
    end,
  })
  
  -- Handle :e or buffer reload for gh://issues buffers
  vim.api.nvim_create_autocmd({ "BufReadCmd", "BufNewFile" }, {
    group = group,
    pattern = "gh://issues",
    callback = function()
      M.open_issue_list(nil)
      return true
    end,
  })
  
  -- Handle :e or buffer reload for gh://issues/* buffers (with repo)
  vim.api.nvim_create_autocmd({ "BufReadCmd", "BufNewFile" }, {
    group = group,
    pattern = "gh://issues/*",
    callback = function(args)
      local repo = args.file:match("^gh://issues/(.+)$")
      M.open_issue_list(repo)
      return true
    end,
  })
  
  -- Handle :e or buffer reload for gh://issue/* buffers (issue detail)
  -- Use both BufReadCmd and BufNewFile to catch all cases
  vim.api.nvim_create_autocmd({ "BufReadCmd", "BufNewFile" }, {
    group = group,
    pattern = { "gh://issue/*", "gh://issue/*/*/*/*" },
    callback = function(args)
      -- Parse: gh://issue/123 or gh://issue/owner/repo/123
      local file = args.file
      local repo, number
      
      -- Try: gh://issue/owner/repo/123
      repo, number = file:match("^gh://issue/([^/]+/[^/]+)/(%d+)$")
      if not number then
        -- Try: gh://issue/123
        number = file:match("^gh://issue/(%d+)$")
      end
      
      if number then
        -- Get current buffer number - this is the buffer being reloaded
        local bufnr = vim.api.nvim_get_current_buf()
        
        -- Mark buffer as loaded to prevent error message
        vim.bo[bufnr].buftype = "acwrite"
        
        -- Fetch and refresh the issue in the current buffer
        cli.get_issue(tonumber(number), repo, function(success, issue, error)
          if not success then
            vim.notify("Failed to fetch issue: " .. (error or "unknown error"), vim.log.levels.ERROR)
            return
          end
          
          -- Format and display issue in the existing buffer
          local lines = format_issue_detail(issue)
          buffer.set_lines(bufnr, lines)
          
          -- Update stored issue data
          vim.api.nvim_buf_set_var(bufnr, "gh_issue_number", tonumber(number))
          vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
          vim.api.nvim_buf_set_var(bufnr, "gh_original_issue", issue)
          
          -- Refresh virtual text metadata
          add_issue_metadata_virtual_text(bufnr)
          
          -- Set up write handler if not already set
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
          
          -- Set filetype
          vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
        end)
      end
      
      return true
    end,
  })
end

-- Export for testing
M._test_parse_issue_list_changes = parse_issue_list_changes

return M
