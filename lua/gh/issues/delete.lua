--- Issue deletion module
local M = {}

local cli = require("gh.cli")
local cache = require("gh.cache")
local config = require("gh.config")

--- Delete issue at cursor position
---@param bufnr integer Buffer number
---@param repo string|nil Repository (owner/repo) or nil for current repo
function M.delete_issue_at_cursor(bufnr, repo)
  -- Get current line
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1]

  if not line then
    vim.notify("No issue on current line", vim.log.levels.WARN)
    return
  end

  -- Extract issue number from line (format: "#123 Title")
  local issue_number = line:match("^#(%d+)")
  if not issue_number then
    vim.notify("No issue number found on current line", vim.log.levels.WARN)
    return
  end

  issue_number = tonumber(issue_number)

  -- Confirmation if enabled
  if config.opts.issue_list.delete_confirmation then
    vim.ui.input({
      prompt = string.format("Delete issue #%d? (y/N): ", issue_number),
    }, function(input)
      if not input or (input:lower() ~= "y" and input:lower() ~= "yes") then
        vim.notify("Deletion cancelled", vim.log.levels.INFO)
        return
      end

      -- Perform deletion
      M.perform_delete(bufnr, repo, issue_number, line_num)
    end)
  else
    -- Delete immediately without confirmation
    M.perform_delete(bufnr, repo, issue_number, line_num)
  end
end

--- Perform the actual deletion
---@param bufnr integer Buffer number
---@param repo string|nil Repository
---@param issue_number number Issue number
---@param _line_num number Line number in buffer (unused, list is refreshed)
function M.perform_delete(bufnr, repo, issue_number, _line_num)
  vim.notify(string.format("Deleting issue #%d...", issue_number), vim.log.levels.INFO)

  cli.delete_issue(repo, issue_number, function(success, error)
    if not success then
      vim.notify(
        string.format("Failed to delete issue #%d: %s", issue_number, error or "unknown error"),
        vim.log.levels.ERROR
      )
      return
    end

    -- Refresh the issue list
    vim.schedule(function()
      -- Check if buffer still exists
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      -- Mark any open detail buffers for this issue as deleted
      M.mark_issue_buffer_as_deleted(issue_number, repo)

      -- Clear cache to force fresh fetch
      local cache_key = "issues_" .. (repo or "current")
      cache.clear(cache_key)

      -- Get current filter state
      local ok, state = pcall(vim.api.nvim_buf_get_var, bufnr, "gh_issues_state")
      if not ok then
        state = "open"
      end

      -- Wait a moment for GitHub to propagate the deletion, then trigger refresh
      vim.defer_fn(function()
        vim.api.nvim_exec_autocmds("User", {
          pattern = "GhIssueDeleted",
          data = {
            issue_number = issue_number,
            repo = repo,
            state = state,
          },
        })
        vim.notify(
          string.format("Issue #%d deleted successfully", issue_number),
          vim.log.levels.INFO
        )
      end, 500)
    end)
  end)
end

--- Mark any open detail buffer for the deleted issue as read-only with warning
---@param issue_number number Issue number
---@param repo string|nil Repository
function M.mark_issue_buffer_as_deleted(issue_number, repo)
  -- Build the buffer name pattern for this issue
  local buf_pattern_with_repo = repo and string.format("gh://issue/%s/%d", repo, issue_number)
  local buf_pattern_no_repo = string.format("gh://issue/%d", issue_number)

  -- Iterate through all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)

      -- Check if this buffer matches the deleted issue (exact match only)
      if buf_name == buf_pattern_with_repo or buf_name == buf_pattern_no_repo then
        -- Add warning message at the top of the buffer
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            -- Temporarily make buffer modifiable
            vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
            vim.api.nvim_set_option_value("readonly", false, { buf = buf })

            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local warning = {
              "⚠️  WARNING: This issue has been deleted from GitHub",
              "",
            }
            -- Insert warning at the top
            for i = #warning, 1, -1 do
              table.insert(lines, 1, warning[i])
            end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

            -- Now mark as read-only and unmodified
            vim.api.nvim_set_option_value("modified", false, { buf = buf })
            vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
            vim.api.nvim_set_option_value("readonly", true, { buf = buf })
          end
        end)
      end
    end
  end
end

return M
