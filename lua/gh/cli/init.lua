--- GitHub CLI wrapper with nested module structure
--- Mirrors gh CLI: gh <command> <subcommand> [flags]
local M = {}

-- Lazy load submodules
M.issue = require("gh.cli.issue")

-- Core runner (for direct gh commands)
M.run = require("gh.cli.core").run

-- Backward compatibility: Keep old API as deprecated wrappers
-- These will be removed in a future version

--- @deprecated Use cli.issue.list instead
function M.list_issues(repo, opts, callback)
  vim.notify_once(
    "cli.list_issues() is deprecated, use cli.issue.list() instead",
    vim.log.levels.WARN
  )

  -- Handle old signature
  if type(repo) == "function" then
    return M.issue.list(repo)
  elseif type(opts) == "function" then
    return M.issue.list({ repo = repo }, opts)
  end

  opts = opts or {}
  opts.repo = repo
  return M.issue.list(opts, callback)
end

--- @deprecated Use cli.issue.view instead
function M.get_issue(number, repo, callback)
  vim.notify_once(
    "cli.get_issue() is deprecated, use cli.issue.view() instead",
    vim.log.levels.WARN
  )
  return M.issue.view(number, repo, callback)
end

--- @deprecated Use cli.issue.create instead
function M.create_issue(opts, callback)
  vim.notify_once(
    "cli.create_issue() is deprecated, use cli.issue.create() instead",
    vim.log.levels.WARN
  )
  return M.issue.create(opts, callback)
end

--- @deprecated Use cli.issue.edit instead
function M.update_title(number, title, repo, callback)
  vim.notify_once(
    "cli.update_title() is deprecated, use cli.issue.edit() instead",
    vim.log.levels.WARN
  )
  return M.issue.edit(number, { title = title }, repo, callback)
end

--- @deprecated Use cli.issue.edit instead
function M.update_body(number, body, repo, callback)
  vim.notify_once(
    "cli.update_body() is deprecated, use cli.issue.edit() instead",
    vim.log.levels.WARN
  )
  return M.issue.edit(number, { body = body }, repo, callback)
end

--- @deprecated Use cli.issue.delete instead
function M.delete_issue(repo, issue_number, callback)
  vim.notify_once(
    "cli.delete_issue() is deprecated, use cli.issue.delete() instead",
    vim.log.levels.WARN
  )
  return M.issue.delete(issue_number, repo, callback)
end

return M
