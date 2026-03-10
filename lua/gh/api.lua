--- GitHub GraphQL API module via 'gh api'
--- Inspired by Snacks.nvim gh module
local M = {}

local Job = require("plenary.job")
local repo_utils = require("gh.utils.repo")

--- Execute gh api GraphQL query
---@param query string GraphQL query
---@param params table<string, any> Query parameters
---@param callback fun(success: boolean, data: table|nil, error: string|nil)
function M.graphql(query, params, callback)
  local args = { "api", "graphql" }

  -- Add query as a raw field
  table.insert(args, "--raw-field")
  table.insert(args, "query=" .. query)

  -- Add parameters
  for key, value in pairs(params or {}) do
    table.insert(args, "--field")
    table.insert(args, string.format("%s=%s", key, tostring(value)))
  end

  Job:new({
    command = "gh",
    args = args,
    on_exit = function(job, return_val)
      if return_val ~= 0 then
        local error_msg = table.concat(job:stderr_result(), "\n")
        vim.schedule(function()
          callback(false, nil, error_msg)
        end)
        return
      end

      local output = table.concat(job:result(), "\n")
      local ok, data = pcall(vim.json.decode, output)

      if not ok then
        vim.schedule(function()
          callback(false, nil, "Failed to parse JSON response")
        end)
        return
      end

      -- Check for GraphQL errors
      if data.errors then
        local error_msgs = {}
        for _, err in ipairs(data.errors) do
          table.insert(error_msgs, err.message)
        end
        vim.schedule(function()
          callback(false, nil, table.concat(error_msgs, "\n"))
        end)
        return
      end

      -- Clean up GraphQL response (remove internal nodes structure)
      local function clean_graphql(tbl)
        for k, v in pairs(tbl) do
          if type(v) == "table" then
            clean_graphql(v)
            -- Unwrap {nodes: [...]} to just the array
            if type(v.nodes) == "table" and vim.tbl_count(v) == 1 then
              tbl[k] = v.nodes
            end
          end
        end
        return tbl
      end

      vim.schedule(function()
        callback(true, clean_graphql(data.data or data), nil)
      end)
    end,
  }):start()
end

--- Get issue details via GraphQL
---@param number integer Issue number
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param callback fun(success: boolean, issue: table|nil, error: string|nil)
function M.get_issue(number, repo, callback)
  -- Determine repository
  if not repo then
    repo_utils.get_current_repo(function(repo_name, error)
      if error then
        callback(false, nil, error)
      else
        M.get_issue(number, repo_name, callback)
      end
    end)
    return
  end

  local owner, name, error = repo_utils.parse_repo(repo)
  if error then
    vim.schedule(function()
      callback(false, nil, error)
    end)
    return
  end

  local query = [[
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        issue(number: $number) {
          id
          number
          title
          body
          state
          stateReason
          author { login }
          createdAt
          updatedAt
          closedAt
          url
          labels(first: 100) {
            nodes {
              name
              color
            }
          }
          assignees(first: 10) {
            nodes {
              login
            }
          }
          milestone {
            title
          }
          reactionGroups {
            content
            users { totalCount }
          }
        }
      }
    }
  ]]

  M.graphql(query, { owner = owner, name = name, number = number }, function(success, data, err)
    if not success then
      callback(false, nil, err)
      return
    end

    local issue = data and data.repository and data.repository.issue
    if not issue then
      callback(false, nil, "Issue not found")
      return
    end

    callback(true, issue, nil)
  end)
end

--- List issues via GraphQL
---@param repo string|nil Repository (owner/repo) or nil for current repo
---@param opts table Options: { limit: number, state: string }
---@param callback fun(success: boolean, issues: table[]|nil, error: string|nil)
function M.list_issues(repo, opts, callback)
  opts = opts or {}

  -- Determine repository
  if not repo then
    repo_utils.get_current_repo(function(repo_name, error)
      if error then
        callback(false, nil, error)
      else
        M.list_issues(repo_name, opts, callback)
      end
    end)
    return
  end

  local owner, name, error = repo_utils.parse_repo(repo)
  if error then
    vim.schedule(function()
      callback(false, nil, error)
    end)
    return
  end

  local limit = opts.limit or 50
  local state_filter = ""
  if opts.state and opts.state:upper() ~= "ALL" then
    state_filter = string.format(", states: [%s]", opts.state:upper())
  end

  local query = string.format(
    [[
    query($owner: String!, $name: String!) {
      repository(owner: $owner, name: $name) {
        issues(first: %d%s, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes {
            id
            number
            title
            body
            state
            stateReason
            author { login }
            createdAt
            updatedAt
            closedAt
            url
            labels(first: 100) {
              nodes {
                name
                color
              }
            }
            assignees(first: 10) {
              nodes {
                login
              }
            }
          }
        }
      }
    }
  ]],
    limit,
    state_filter
  )

  M.graphql(query, { owner = owner, name = name }, function(success, data, err)
    if not success then
      callback(false, nil, err)
      return
    end

    local issues = data and data.repository and data.repository.issues
    if not issues then
      callback(false, nil, "No issues found")
      return
    end

    callback(true, issues, nil)
  end)
end

return M
