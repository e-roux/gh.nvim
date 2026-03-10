--- Issue close/reopen module (gh issue close/reopen)
local M = {}

local cli = require("gh.cli")
local cache = require("gh.cache")

--- Close issue
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo)
---@param opts? table Options (comment, reason)
function M.close_issue(number, repo, opts)
  opts = opts or {}
  cli.issue.close(
    number,
    { repo = repo, comment = opts.comment, reason = opts.reason },
    function(success, error)
      if success then
        vim.notify(string.format("Issue #%d closed", number), vim.log.levels.INFO)
        -- Clear issue list cache as it might have changed
        cache.clear("issues_list_" .. (repo or "current"))
      else
        vim.notify(
          string.format("Failed to close issue #%d: %s", number, error or "unknown error"),
          vim.log.levels.ERROR
        )
      end
    end
  )
end

--- Reopen issue
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo)
---@param opts? table Options (comment)
function M.reopen_issue(number, repo, opts)
  opts = opts or {}
  cli.issue.reopen(number, { repo = repo, comment = opts.comment }, function(success, error)
    if success then
      vim.notify(string.format("Issue #%d reopened", number), vim.log.levels.INFO)
      -- Clear issue list cache
      cache.clear("issues_list_" .. (repo or "current"))
    else
      vim.notify(
        string.format("Failed to reopen issue #%d: %s", number, error or "unknown error"),
        vim.log.levels.ERROR
      )
    end
  end)
end

--- Get issue completions (only open issues for close, only closed for reopen)
---@param repo string|nil Repository
---@param state string Issue state: "open", "closed"
---@param callback fun(issues: table[]|nil)
function M.get_issue_completions(repo, state, callback)
  local cache_key = string.format("issues_completion_%s_%s", repo or "current", state)

  cache.get_or_fetch(
    cache_key,
    function(cb)
      cli.issue.list({ repo = repo, state = state, limit = 100 }, function(success, issues, _error)
        if success then
          cb(issues)
        else
          cb(nil)
        end
      end)
    end,
    300, -- 5 minutes TTL
    callback
  )
end

return M
