--- GitHub issue CLI operations (gh issue)
local M = {}

local core = require("gh.cli.core")

--- List issues (gh issue list)
---@param opts? table Options
---  - state? string Issue state: "open", "closed", "all" (default: "open")
---  - limit? integer Number of issues to fetch (default: 30)
---  - assignee? string Filter by assignee
---  - author? string Filter by author
---  - label? string|string[] Filter by label(s)
---  - mention? string Filter by mention
---  - milestone? string Filter by milestone
---  - search? string Search query
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, issues: table[]|nil, error: string|nil)
function M.list(opts, callback)
  -- Handle signature: list(callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "issue", "list" }

  -- Add flags
  core.add_flag(args, "--state", opts.state or "open")
  core.add_flag(args, "--limit", opts.limit or 30)
  core.add_flag(args, "--assignee", opts.assignee)
  core.add_flag(args, "--author", opts.author)
  core.add_flag(args, "--mention", opts.mention)
  core.add_flag(args, "--milestone", opts.milestone)
  core.add_flag(args, "--search", opts.search)
  core.add_array_flag(args, "--label", opts.label)
  core.add_repo_flag(args, opts.repo)

  -- Request JSON output
  table.insert(args, "--json")
  table.insert(args, "number,title,state,labels,assignees,author,createdAt,updatedAt")

  core.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    local ok, issues, parse_error = core.parse_json(result)
    if not ok then
      callback(false, nil, parse_error)
      return
    end

    callback(true, issues, nil)
  end)
end

--- View issue details (gh issue view)
---@param number integer Issue number
---@param opts? table|string Options table or repo string (for backward compat)
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, issue: table|nil, error: string|nil)
function M.view(number, opts, callback)
  -- Handle signature: view(number, repo, callback) - backward compat
  if type(opts) == "string" then
    local repo = opts
    opts = { repo = repo }
  elseif type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "issue", "view", tostring(number) }

  core.add_repo_flag(args, opts.repo)

  -- Request JSON output
  table.insert(args, "--json")
  table.insert(args, "number,title,body,state,labels,assignees,author,createdAt,updatedAt,url")

  core.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    local ok, issue, parse_error = core.parse_json(result)
    if not ok then
      callback(false, nil, parse_error)
      return
    end

    callback(true, issue, nil)
  end)
end

--- Create issue (gh issue create)
---@param opts table Options
---  - title string Issue title (required)
---  - body? string Issue body
---  - assignee? string|string[] Assignee username(s)
---  - label? string|string[] Label(s)
---  - milestone? string Milestone
---  - project? string Project
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, issue: table|nil, error: string|nil)
function M.create(opts, callback)
  local args = { "issue", "create", "--title", opts.title }

  core.add_flag(args, "--body", opts.body)
  core.add_array_flag(args, "--assignee", opts.assignee)
  core.add_array_flag(args, "--label", opts.label)
  core.add_flag(args, "--milestone", opts.milestone)
  core.add_flag(args, "--project", opts.project)
  core.add_repo_flag(args, opts.repo)

  core.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    -- Parse issue URL from output
    local url = result:match("https://github.com/[^/]+/[^/]+/issues/(%d+)")
    if url then
      callback(true, { number = tonumber(url), url = result }, nil)
    else
      callback(true, { url = result }, nil)
    end
  end)
end

--- Edit issue (gh issue edit)
---@param number integer Issue number
---@param fields table Fields to update
---  - title? string New title
---  - body? string New body
---  - state? string New state ("open" or "closed")
---  - assignee? string|string[] Assignee(s) to add
---  - label? string|string[] Label(s) to add
---@param opts? table|string Options table or repo string (for backward compat)
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, error: string|nil)
function M.edit(number, fields, opts, callback)
  -- Handle signature: edit(number, fields, repo, callback) - backward compat
  if type(opts) == "string" then
    local repo = opts
    opts = { repo = repo }
  elseif type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "issue", "edit", tostring(number) }

  core.add_flag(args, "--title", fields.title)
  core.add_flag(args, "--body", fields.body)
  core.add_flag(args, "--state", fields.state)
  core.add_array_flag(args, "--add-assignee", fields.assignee)
  core.add_array_flag(args, "--add-label", fields.label)
  core.add_repo_flag(args, opts.repo)

  core.run(args, function(success, _, error)
    callback(success, error)
  end)
end

--- Delete issue (gh issue delete)
---@param number integer Issue number
---@param opts? table|string Options table or repo string (for backward compat)
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, error: string|nil)
function M.delete(number, opts, callback)
  -- Handle signature: delete(number, repo, callback) - backward compat
  if type(opts) == "string" then
    local repo = opts
    opts = { repo = repo }
  elseif type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "issue", "delete", tostring(number), "--yes" }

  core.add_repo_flag(args, opts.repo)

  core.run(args, function(success, _, error)
    callback(success, error)
  end)
end

--- Close issue (gh issue close)
---@param number integer Issue number
---@param opts? table Options
---  - comment? string Close comment
---  - reason? string Reason: "completed", "not planned"
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, error: string|nil)
function M.close(number, opts, callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "issue", "close", tostring(number) }

  core.add_flag(args, "--comment", opts.comment)
  core.add_flag(args, "--reason", opts.reason)
  core.add_repo_flag(args, opts.repo)

  core.run(args, function(success, _, error)
    if callback then
      callback(success, error)
    end
  end)
end

--- Reopen issue (gh issue reopen)
---@param number integer Issue number
---@param opts? table Options
---  - comment? string Reopen comment
---  - repo? string Repository (owner/repo)
---@param callback fun(success: boolean, error: string|nil)
function M.reopen(number, opts, callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end

  opts = opts or {}
  local args = { "issue", "reopen", tostring(number) }

  core.add_flag(args, "--comment", opts.comment)
  core.add_repo_flag(args, opts.repo)

  core.run(args, function(success, _, error)
    if callback then
      callback(success, error)
    end
  end)
end

return M
