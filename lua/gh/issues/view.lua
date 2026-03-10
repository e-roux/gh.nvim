--- Issue view module (gh issue view)
local M = {}

local buffer = require("gh.ui.buffer")
local cli = require("gh.cli")

--- Format issue detail for display
---@param issue table Issue data
---@return string[] Formatted lines
function M.format_issue_detail(issue)
  local lines = {}

  -- Title
  table.insert(lines, "# " .. issue.title)
  -- Body
  if issue.body and issue.body ~= "" then
    for line in (issue.body .. "\n"):gmatch("([^\n]*)\n") do
      table.insert(lines, line)
    end
  else
    table.insert(lines, "_No description provided._")
  end

  return lines
end

--- Parse issue detail from buffer lines
---@param lines string[] Buffer lines
---@return table Parsed issue { title: string, body: string }
function M.parse_issue_detail(lines)
  local title = ""
  local body_lines = {}
  local in_body = false

  local separator = string.rep("━", 80)
  for _, line in ipairs(lines) do
    if line:match("^#%s+") and not in_body then
      -- Title line
      title = line:gsub("^#%s+", "")
    elseif line:find(separator, 1, true) and not in_body then
      -- Separator found! The body starts after the next line (which is a blank line we added)
      in_body = true
      -- The separator is followed by a blank line, so skip it by looking at the index
      -- This loop will handle it in the next iterations
    elseif in_body then
      -- If it's the first line after separator, and it's blank, skip it once
      if not (#body_lines == 0 and line == "") then
        table.insert(body_lines, line)
      end
    end
  end

  return {
    title = title,
    body = table.concat(body_lines, "\n"),
  }
end

--- Add virtual text metadata to issue buffer
---@param bufnr integer Buffer number
function M.add_issue_metadata_virtual_text(bufnr)
  local ok, issue = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_original_issue")
  if not ok or not issue then
    return
  end

  -- Use the render module which now uses components
  local render = require("gh.ui.render")
  render.render_metadata(bufnr, issue)
end

--- Open issue detail buffer for viewing/editing (gh issue view)
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo) or nil for current repo
function M.open_issue_detail(number, repo)
  cli.issue.view(number, repo, function(success, issue, error)
    if not success then
      vim.notify("Failed to fetch issue: " .. (error or "unknown error"), vim.log.levels.ERROR)
      return
    end

    -- Create buffer
    local buf_name = repo and string.format("gh://issue/%s/%d", repo, number)
      or string.format("gh://issue/%d", number)
    local bufnr = buffer.create_scratch(buf_name)

    -- Format and display issue
    local lines = M.format_issue_detail(issue)
    buffer.set_lines(bufnr, lines)

    -- Store original issue
    vim.api.nvim_buf_set_var(bufnr, "gh_issue_number", number)
    vim.api.nvim_buf_set_var(bufnr, "gh_repo", repo or "")
    vim.api.nvim_buf_set_var(bufnr, "gh_original_issue", issue)

    -- Add virtual text metadata
    M.add_issue_metadata_virtual_text(bufnr)

    -- Set up write handler
    buffer.on_write(bufnr, function(buf)
      local current_lines = buffer.get_lines(buf)
      local parsed = M.parse_issue_detail(current_lines)
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
        cli.issue.edit(
          issue_number,
          { title = parsed.title },
          target_repo,
          function(title_success, err)
            pending = pending - 1
            if not title_success then
              table.insert(errors, "title: " .. (err or "unknown"))
            end
          end
        )
      end

      -- Update body if changed
      if parsed.body ~= original.body then
        pending = pending + 1
        cli.issue.edit(
          issue_number,
          { body = parsed.body },
          target_repo,
          function(body_success, err)
            pending = pending - 1
            if not body_success then
              table.insert(errors, "body: " .. (err or "unknown"))
            end
          end
        )
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

      -- Trigger refresh of list buffers
      vim.schedule(function()
        vim.api.nvim_exec_autocmds("User", {
          pattern = "GhIssueUpdated",
          data = {
            issue_number = issue_number,
            repo = target_repo,
            title = parsed.title,
          },
        })
      end)

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

    -- Set up autocmd to refresh issue metadata on updates
    local view_group = vim.api.nvim_create_augroup("GhIssueViewRefresh_" .. bufnr, { clear = true })
    vim.api.nvim_create_autocmd("User", {
      group = view_group,
      pattern = "GhIssueUpdated",
      callback = function(event)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        local event_issue_number = event.data.issue_number
        local event_repo = event.data.repo

        if event_issue_number == number and (event_repo or "") == (repo or "") then
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end

            M.add_issue_metadata_virtual_text(bufnr)
          end)
        end
      end,
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

return M
