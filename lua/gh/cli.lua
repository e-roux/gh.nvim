--- GitHub CLI wrapper module
local M = {}

--- Run gh command asynchronously
---@param args string[] Command arguments
---@param callback fun(success: boolean, result: string|nil, error: string|nil)
function M.run(args, callback)
  local Job = require("plenary.job")

  Job:new({
    command = "gh",
    args = args,
    on_exit = function(j, return_val)
      vim.schedule(function()
        if return_val ~= 0 then
          local error_msg = table.concat(j:stderr_result(), "\n")
          callback(false, nil, error_msg)
        else
          local result = table.concat(j:result(), "\n")
          callback(true, result, nil)
        end
      end)
    end,
  }):start()
end

--- List issues for a repository
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param opts table|nil Options: { limit: number, state: string }
---@param callback fun(success: boolean, issues: table[]|nil, error: string|nil)
function M.list_issues(repo, opts, callback)
  -- Handle old signature: list_issues(repo, callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end
  
  opts = opts or {}
  local limit = opts.limit or 30
  local state = opts.state or "open"
  
  local args = { 
    "issue", "list", 
    "--json", "number,title,state,labels,assignees,author,createdAt,updatedAt",
    "--limit", tostring(limit),
    "--state", state
  }
  if repo then
    table.insert(args, "--repo")
    table.insert(args, repo)
  end

  M.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    local ok, issues = pcall(vim.json.decode, result)
    if not ok then
      callback(false, nil, "Failed to parse JSON response")
      return
    end

    callback(true, issues, nil)
  end)
end

--- Get issue details
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, issue: table|nil, error: string|nil)
function M.get_issue(number, repo, callback)
  local args = { "issue", "view", tostring(number), "--json", "number,title,body,state,labels,assignees,author,createdAt,updatedAt,url" }
  if repo then
    table.insert(args, "--repo")
    table.insert(args, repo)
  end

  M.run(args, function(success, result, error)
    if not success then
      callback(false, nil, error)
      return
    end

    local ok, issue = pcall(vim.json.decode, result)
    if not ok then
      callback(false, nil, "Failed to parse JSON response")
      return
    end

    callback(true, issue, nil)
  end)
end

--- Update issue title
---@param number integer Issue number
---@param title string New title
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, error: string|nil)
function M.update_title(number, title, repo, callback)
  local args = { "issue", "edit", tostring(number), "--title", title }
  if repo then
    table.insert(args, "--repo")
    table.insert(args, repo)
  end

  M.run(args, function(success, _, error)
    callback(success, error)
  end)
end

--- Update issue body
---@param number integer Issue number
---@param body string New body
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, error: string|nil)
function M.update_body(number, body, repo, callback)
  local args = { "issue", "edit", tostring(number), "--body", body }
  if repo then
    table.insert(args, "--repo")
    table.insert(args, repo)
  end

  M.run(args, function(success, _, error)
    callback(success, error)
  end)
end

return M
